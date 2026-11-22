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
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = resolve(__dirname, '..');

let VERSION = '2.0.0';
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
  init [name] [path]        Initialize SKILL MAESTRO in a new project (interactive by default)
                            Options: --stack <name>, --lang <en|es>, --copy, --ci, -i
  adopt [name] [path]       Adopt an existing brownfield repository without altering code
                            Options: --stack <name>, --lang <en|es>, --copy, --ci, -i
  wizard                    Launch interactive onboarding wizard step-by-step
  kickoff                   Run pre-flight environment checks (Node, Python, Git, Docker, ports)
  doctor [--kickoff]        Run 5-stage health check, secret scan, and brain linter
  update [path]             Update installed skills, hooks, and scripts to latest
  serve [--port <port>]     Start real-time interactive Live Dashboard (default: 4200)
  ui                        Alias for 'serve'
  swarm [status|list|run]   Coordinate concurrent multi-agent branches & workspaces
  seed [--count N] [--fmt]  Generate realistic synthetic seed test data (JSON/SQL)
  stress [--url URL]        Run HTTP load & resilience simulator (p50/p95/p99)
  audit [report]            Generate executive compliance & governance audit report
  mock [--port <port>]      Start autonomous API Mock Server from contracts.json
  mcp [--port <port>]       Start native Model Context Protocol (MCP) server (stdio or SSE)
  task <subcommand> [...]   Execute task.sh commands (list, add, start, close, doctor, etc.)

Examples:
  npx skill-maestro init
  npx skill-maestro init "My App" ./my-app --stack nextjs --lang es --ci
  npx skill-maestro adopt ./existing-repo
  npx skill-maestro kickoff
  npx skill-maestro serve --port 4200
  npx skill-maestro stress --url http://127.0.0.1:4200/api/status -c 5 -n 20
  npx skill-maestro audit report --format html
  npx skill-maestro seed --count 20 --format sql
  npx skill-maestro swarm run TASK-001 TASK-002 --parallel 2
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

/**
 * Asistente interactivo paso a paso para inicialización de proyectos.
 */
async function runInteractiveWizard(defaultMode = 'init') {
  printBanner();
  console.log(`🧙 Bienvenido al Asistente Interactivo de SKILL MAESTRO\n`);

  const rl = createInterface({ input, output });

  try {
    let mode = defaultMode;
    if (defaultMode === 'wizard') {
      const modeAns = await rl.question(
        `¿Qué deseas hacer?\n  1) Crear un nuevo proyecto desde cero (init)\n  2) Adoptar un proyecto existente (adopt)\nSelecciona [1/2] (por defecto 1): `
      );
      mode = modeAns.trim() === '2' ? 'adopt' : 'init';
      console.log('');
    }

    const defaultName = mode === 'adopt' ? basename(process.cwd()) : 'Mi Proyecto';
    const nameAns = await rl.question(`1. Nombre del proyecto [${defaultName}]: `);
    const projectName = nameAns.trim() || defaultName;

    const defaultDir = mode === 'adopt' ? '.' : `./${projectName.toLowerCase().replace(/[^a-z0-9_-]+/g, '-')}`;
    const dirAns = await rl.question(`2. Directorio de destino [${defaultDir}]: `);
    const targetDir = dirAns.trim() || defaultDir;

    console.log(`\n3. Selecciona el stack tecnológico:`);
    console.log(`  1) Next.js 15 (React 19, Tailwind, Prisma, PostgreSQL) [nextjs]`);
    console.log(`  2) Angular 22 (Express 5, Drizzle, PostgreSQL) [angular]`);
    console.log(`  3) FastAPI (Python, SQLAlchemy 2, PostgreSQL) [fastapi]`);
    console.log(`  4) Nuxt 3 (Vue 3, Nitro, Drizzle, PostgreSQL) [nuxt]`);
    console.log(`  5) React 19 + Vite (Node, Tailwind) [react-vite]`);
    console.log(`  6) NestJS (TypeScript, Prisma, PostgreSQL) [nestjs]`);
    console.log(`  7) Personalizado / Definir después en /iniciar-proyecto`);
    const stackAns = await rl.question(`Elige una opción [1-7] (por defecto 1): `);

    let stack = 'nextjs';
    switch (stackAns.trim()) {
      case '2': stack = 'angular'; break;
      case '3': stack = 'fastapi'; break;
      case '4': stack = 'nuxt'; break;
      case '5': stack = 'react-vite'; break;
      case '6': stack = 'nestjs'; break;
      case '7': stack = ''; break;
      default: stack = 'nextjs'; break;
    }

    const langAns = await rl.question(`\n4. Idioma de gobernanza y plantillas (1: es [Español], 2: en [English]) [1]: `);
    const lang = langAns.trim() === '2' ? 'en' : 'es';

    const ciAns = await rl.question(`\n5. ¿Instalar pipeline CI de GitHub Actions? (S/n): `);
    const installCi = ciAns.trim().toLowerCase() !== 'n';

    const copyAns = await rl.question(`\n6. ¿Copiar archivos físicamente (--copy)? Recomendado para portabilidad (S/n): `);
    const copyMode = copyAns.trim().toLowerCase() !== 'n';

    rl.close();

    console.log(`\n🚀 Configurando entorno con SKILL MAESTRO...\n`);

    const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
    const scriptArgs = [];

    if (mode === 'adopt') {
      scriptArgs.push('--adopt');
    }
    scriptArgs.push(projectName, targetDir);

    if (stack) {
      scriptArgs.push('--stack', stack);
    }
    scriptArgs.push('--lang', lang);

    if (installCi) {
      scriptArgs.push('--ci');
    }
    if (copyMode) {
      scriptArgs.push('--copy');
    }

    runScript('bash', [initScript, ...scriptArgs]);
  } catch (err) {
    rl.close();
    console.error(`\n❌ Error en el asistente: ${err.message}`);
    process.exit(1);
  }
}

async function main() {
  switch (command) {
    case 'wizard': {
      await runInteractiveWizard('wizard');
      break;
    }
    case 'kickoff': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'doctor', '--kickoff']);
      break;
    }
    case 'init': {
      const isInteractiveFlag = args.includes('--interactive') || args.includes('-i');
      const hasPositionalArgs = args.slice(1).some((a) => !a.startsWith('-'));

      if ((isInteractiveFlag || !hasPositionalArgs) && process.stdin.isTTY) {
        await runInteractiveWizard('init');
      } else {
        const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
        runScript('bash', [initScript, ...args.slice(1)]);
      }
      break;
    }
    case 'adopt': {
      const isInteractiveFlag = args.includes('--interactive') || args.includes('-i');
      const hasPositionalArgs = args.slice(1).some((a) => !a.startsWith('-'));

      if ((isInteractiveFlag || !hasPositionalArgs) && process.stdin.isTTY) {
        await runInteractiveWizard('adopt');
      } else {
        const initScript = resolve(PKG_ROOT, '.agents/scripts/init-project.sh');
        runScript('bash', [initScript, '--adopt', ...args.slice(1)]);
      }
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
    case 'mock': {
      const mockScript = resolve(PKG_ROOT, '.agents/scripts/contracts-mock.py');
      runScript('python3', [mockScript, ...args.slice(1)]);
      break;
    }
    case 'contracts': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'contracts', ...args.slice(1)]);
      break;
    }
    case 'swarm': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'swarm', ...args.slice(1)]);
      break;
    }
    case 'seed': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'seed', ...args.slice(1)]);
      break;
    }
    case 'stress': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'stress', ...args.slice(1)]);
      break;
    }
    case 'audit': {
      const localTaskSh = resolve(process.cwd(), '.agents/scripts/task.sh');
      const taskSh = existsSync(localTaskSh) ? localTaskSh : resolve(PKG_ROOT, '.agents/scripts/task.sh');
      runScript('bash', [taskSh, 'audit', ...args.slice(1)]);
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
}

main();
