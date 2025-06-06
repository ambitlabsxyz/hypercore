import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load the current package.json
const packagePath = path.resolve(process.cwd(), "package.json");
const pkgRaw = await fs.readFile(packagePath, "utf8");
const pkg = JSON.parse(pkgRaw);

// Load the root package.json (assumed two levels up)
const rootPath = path.resolve(__dirname, "../package.json");
const rootRaw = await fs.readFile(rootPath, "utf8");
const rootPkg = JSON.parse(rootRaw);

// Collect versions of all workspace packages
const workspaceVersions = {};

for (const pattern of rootPkg.workspaces || []) {
  const baseDir = path.resolve(__dirname, "../", pattern.replace("/*", ""));
  const dirs = await fs.readdir(baseDir);
  for (const dir of dirs) {
    const subPkgPath = path.join(baseDir, dir, "package.json");
    try {
      const subPkgRaw = await fs.readFile(subPkgPath, "utf8");
      const subPkg = JSON.parse(subPkgRaw);
      workspaceVersions[subPkg.name] = subPkg.version;
    } catch {
      // Skip if not a valid package
    }
  }
}

function replaceDeps(deps) {
  if (!deps) return;
  for (const [dep, version] of Object.entries(deps)) {
    if (version.startsWith("workspace:")) {
      const actualVersion = workspaceVersions[dep];
      if (actualVersion) {
        deps[dep] = `^${actualVersion}`;
        console.log(`Replaced ${dep} -> ^${actualVersion}`);
      } else {
        console.warn(`Warning: No version found for ${dep}`);
      }
    }
  }
}

// Replace all types of deps
replaceDeps(pkg.dependencies);
replaceDeps(pkg.devDependencies);
replaceDeps(pkg.peerDependencies);

// Write updated package.json
await fs.writeFile(packagePath, JSON.stringify(pkg, null, 2));
console.log(`✅ Updated ${packagePath}`);
