#!/usr/bin/env node
/**
 * SKILL MAESTRO CLI - Multi-Agent Engineering Operating System
 * Created by Klisman Vizcarra
 *
 * Universal command-line interface for initializing, governing, and running
 * multi-agent software engineering workflows in Claude Code & Antigravity.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = resolve(__dirname, '..');

let VERSION = '2.0.0-beta.1';
try {
  const vPath = resolve(PKG_ROOT, '.agents/VERSION');
  if (existsSync(vPath)) {
    VERSION = readFileSync(vPath, 'utf-8').trim();
  }
} catch {}

function printBanner() {
  console.log(`╔═══════════════════════════════════════════════════════════════════╗`);
  console.log(`║   SKILL MAESTRO · Multi-Agent Engineering Operating System        ║`);
  console.log(`╠═══════════════════════════════════════════════════════════════════╣`);
  console.log(`║ • Creator: Klisman Vizcarra      • Version: v${VERSION.padEnd(20)}║`);
  console.log(`╚═══════════════════════════════════════════════════════════════════╝\n`);
}

function printHelp() {
  printBanner();
  console.log(`Usage:
  npx skill-maestro <command> [options]
  maestro <command> [options]

Commands:
  init [name] [path]        Initialize SKILL MAESTRO in a new project
                            Options: --stack <name>, --lang <en|es>, --copy, --ci
  adopt [name] [path]       Adopt an existing brownfield repository
                            Options: --stack <name>, --lang <en|es>, --copy, --ci
  update [path]             Update installed skills, hooks, and scripts to latest
  serve [--port <port>]     Start real-time interactive Live Dashboard (default: 4200)
  ui                        Alias for 'serve'
  doctor                    Run 5-stage health check, secret scan, and brain linter
  mcp                       Start the native Model Context Protocol (MCP) server
  task <subcommand> [...]   Execute task.sh commands (list, add, start, close, etc.)

Examples:
  npx skill-maestro init "My App" ./my-app --stack nextjs --lang en
  npx skill-maestro adopt ./existing-repo
  npx skill-maestro serve --port 4200
  npx skill-maestro doctor

Learn more at:
  https://github.com/klismanvizcarra-maker/expertise-in-software-development
`);
}

const args = process.argv.slice(2);
const command = args[0];

if (!command || command === '--help' || command === '-h' || command === 'help') {
  printHelp();
  process.exit(0);
}

if (command === '--version' || command === '-v' || command === 'version') {
  console.log(`skill-maestro v${VERSION} (created by Klisman Vizcarra)`);
  process.exit(0);
}

function runScript(cmd, scriptArgs, cwd = process.cwd()) {
  const result = spawnSync(cmd, scriptArgs, {
    cwd,
    stdio: 'inherit',
    env: process.env,
  });
  if (result.error) {
    console.error(`❌ Execution error: ${result.error.message}`);
    process.exit(1);
  }
  process.exit(result.status ?? 0);
}

switch (command) {
  case 'init': {
    const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
    runScript('bash', [initScript, ...args.slice(1)]);
    break;
  }
  case 'adopt': {
    const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
    runScript('bash', [initScript, '--adopt', ...args.slice(1)]);
    break;
  }
  case 'update': {
    const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
    runScript('bash', [initScript, '--update', ...args.slice(1)]);
    break;
  }
  case 'serve':
  case 'ui': {
    const serverScript = resolve(PKG_ROOT, '.agents/scripts/dashboard-server.py');
    runScript('python3', [serverScript, ...args.slice(1)]);
    break;
  }
  case 'doctor': {
    const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
    const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
    runScript('bash', [taskSh, 'doctor', ...args.slice(1)]);
    break;
  }
  case 'mcp': {
    const mcpServer = resolve(PKG_ROOT, '.agents/mcp/server.mjs');
    runScript('node', [mcpServer, ...args.slice(1)]);
    break;
  }
  case 'task': {
    const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
    const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
    runScript('bash', [taskSh, ...args.slice(1)]);
    break;
  }
  default: {
    console.error(`❌ Unknown command: '${command}'`);
    console.error(`Run 'skill-maestro --help' for available commands.\n`);
    process.exit(1);
  }
}
