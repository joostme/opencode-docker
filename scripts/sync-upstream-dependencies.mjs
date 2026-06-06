import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

const dockerfilePath = new URL("../Dockerfile", import.meta.url);
const packageJsonPath = new URL("../package.json", import.meta.url);
const changesetDir = new URL("../.changeset/", import.meta.url);

const dockerfile = readFileSync(dockerfilePath, "utf8");
const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));
const packageName = packageJson.name;

const dependencies = [
  {
    key: "OPENCODE_VERSION",
    repo: "anomalyco/opencode",
    label: "opencode",
    changesetSummary: "chore(deps): update opencode to"
  },
  {
    key: "GH_VERSION",
    repo: "cli/cli",
    label: "github cli",
    changesetSummary: "chore(deps): update github cli to"
  },
  {
    key: "CODE_SERVER_VERSION",
    repo: "coder/code-server",
    label: "code-server",
    changesetSummary: "chore(deps): update code-server to"
  }
];

function getPinnedVersion(content, key) {
  const match = content.match(new RegExp(`^ARG ${key}=(.+)$`, "m"));
  if (!match) {
    throw new Error(`Could not find ${key} in Dockerfile`);
  }

  return match[1].trim();
}

function getLatestVersion(repo) {
  const output = execFileSync(
    "gh",
    ["api", `repos/${repo}/releases/latest`, "--jq", ".tag_name"],
    { encoding: "utf8" }
  ).trim();

  return output.replace(/^v/, "");
}

function updateDockerfile(content, updates) {
  let nextContent = content;

  for (const update of updates) {
    nextContent = nextContent.replace(
      new RegExp(`^ARG ${update.key}=.+$`, "m"),
      `ARG ${update.key}=${update.latest}`
    );
  }

  return nextContent;
}

function getChangesetPath(update) {
  const slug = update.label.replace(/[^a-z0-9]+/gi, "-").toLowerCase();
  const fileName = `deps-${slug}-${update.latest}.md`;
  return join(fileURLToPath(changesetDir), fileName);
}

function writeChangesetFile(update) {
  const filePath = getChangesetPath(update);
  const content = `---\n"${packageName}": patch\n---\n\n${update.changesetSummary} v${update.latest}\n`;

  writeFileSync(filePath, content);
}

const updates = dependencies
  .map((dependency) => {
    const current = getPinnedVersion(dockerfile, dependency.key);
    const latest = getLatestVersion(dependency.repo);
    return { ...dependency, current, latest };
  })
  .filter((dependency) => dependency.current !== dependency.latest);

if (updates.length === 0) {
  console.log("No upstream dependency updates found.");
  process.exit(0);
}

writeFileSync(dockerfilePath, updateDockerfile(dockerfile, updates));

for (const update of updates) {
  writeChangesetFile(update);
}

for (const update of updates) {
  console.log(`${update.label}: ${update.current} -> ${update.latest}`);
}
