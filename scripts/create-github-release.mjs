import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
const version = pkg.version;
const tag = `v${version}`;
const repository = process.env.GITHUB_REPOSITORY;
const sha = process.env.GITHUB_SHA;
const githubOutput = process.env.GITHUB_OUTPUT;

if (!repository || !sha) {
  throw new Error("GITHUB_REPOSITORY and GITHUB_SHA must be set");
}

const image = `ghcr.io/${repository.toLowerCase()}`;
const prerelease = version.includes("-");
const channel = prerelease ? version.split("-")[1].split(".")[0] : null;

function setOutput(name, value) {
  if (!githubOutput) {
    return;
  }

  appendFileSync(githubOutput, `${name}=${value}\n`);
}

setOutput("build", "false");
setOutput("version", version);
setOutput("tag", tag);
setOutput("image", image);

function extractLatestReleaseNotes() {
  if (!existsSync("CHANGELOG.md")) {
    return "";
  }

  const lines = readFileSync("CHANGELOG.md", "utf8").split("\n");
  const heading = new RegExp(`^##\\s+v?${version.replace(/\./g, "\\.")}(?:\\s|$)`);
  const start = lines.findIndex((line) => heading.test(line));

  if (start === -1) {
    return "";
  }

  let end = lines.length;
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^##\s+/.test(lines[i])) {
      end = i;
      break;
    }
  }

  return lines.slice(start + 1, end).join("\n").trim();
}

function releaseExists() {
  try {
    execFileSync("gh", ["release", "view", tag], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

async function imageExists() {
  const name = image.replace(/^ghcr\.io\//, "");
  const credentials = Buffer.from(`token:${process.env.GITHUB_TOKEN}`).toString("base64");
  const tokenResponse = await fetch(`https://ghcr.io/token?scope=repository:${name}:pull`, {
    headers: { Authorization: `Basic ${credentials}` }
  });
  const { token } = await tokenResponse.json();
  const response = await fetch(`https://ghcr.io/v2/${name}/manifests/${version}`, {
    method: "HEAD",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json"
    }
  });
  return response.ok;
}

if (releaseExists()) {
  // A failed or re-run job can leave a release without its image, so build it then.
  if (await imageExists()) {
    console.log(`Release ${tag} and image ${image}:${version} already exist, skipping`);
  } else {
    console.log(`Release ${tag} exists but image ${image}:${version} is missing, building it`);
    setOutput("build", "true");
  }
  process.exit(0);
}

const changelogNotes = extractLatestReleaseNotes();
const releaseNotes = [
  changelogNotes,
  "## Container Image",
  `- \`${image}:${version}\``,
  prerelease ? `- \`${image}:${channel}\`` : `- \`${image}:latest\``
]
  .filter(Boolean)
  .join("\n\n");

writeFileSync("release-notes.md", `${releaseNotes}\n`);

execFileSync(
  "gh",
  [
    "release",
    "create",
    tag,
    "--title",
    tag,
    "--notes-file",
    "release-notes.md",
    "--target",
    sha,
    ...(prerelease ? ["--prerelease"] : [])
  ],
  { stdio: "inherit" }
);

setOutput("build", "true");
