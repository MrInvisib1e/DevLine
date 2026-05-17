// .opencode/plugins/devline.js
// Devline OpenCode plugin — injects bootstrap skill, registers skills dir, adds bin/ to PATH
import { readFileSync } from "fs"
import { join, dirname } from "path"
import { fileURLToPath } from "url"

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = join(__dirname, "../..")  // devline root

function getBootstrapContent() {
  const skillPath = join(ROOT, "skills/using-devline/SKILL.md")
  let content
  try {
    content = readFileSync(skillPath, "utf8")
  } catch {
    return ""
  }
  // Strip YAML frontmatter
  content = content.replace(/^---[\s\S]*?---\n/, "")
  return content.trim()
}

export default {
  name: "devline",

  config(config) {
    // Register skills directory for skill discovery
    config.skills = config.skills || []
    if (!config.skills.includes(join(ROOT, "skills"))) {
      config.skills.push(join(ROOT, "skills"))
    }

    // Add bin/ to PATH so dl-init, dl-sync, etc. are available
    const binDir = join(ROOT, "bin")
    const currentPath = process.env.PATH || ""
    if (!currentPath.includes(binDir)) {
      process.env.PATH = `${binDir}:${currentPath}`
    }

    return config
  },

  "experimental.chat.messages.transform"(messages) {
    if (!messages || messages.length === 0) return messages

    const bootstrap = getBootstrapContent()
    if (!bootstrap) return messages

    const wrapped = `<DEVLINE_ACTIVE>\n${bootstrap}\n</DEVLINE_ACTIVE>`

    // Prepend to first user message only
    const first = messages[0]
    if (first.role === "user") {
      const content = Array.isArray(first.content)
        ? [{ type: "text", text: wrapped }, ...first.content]
        : [{ type: "text", text: wrapped }, { type: "text", text: first.content }]
      return [{ ...first, content }, ...messages.slice(1)]
    }

    return messages
  }
}
