import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
const version = pkg.version;
const tag = `v${version}`;
const repository = process.env.GITHUB_REPOSITORY;
const sha = process.env.GITHUB_SHA;

if (!repository || !sha) {
  throw new Error("GITHUB_REPOSITORY and GITHUB_SHA must be set");
}

const image = `ghcr.io/${repository.toLowerCase()}`;

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

if (releaseExists()) {
  console.log(`Release ${tag} already exists, skipping`);
  process.exit(0);
}

const changelogNotes = extractLatestReleaseNotes();
const releaseNotes = [
  changelogNotes,
  "## Container Image",
  `- \`${image}:${version}\``,
  `- \`${image}:latest\``
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
    sha
  ],
  { stdio: "inherit" }
);
