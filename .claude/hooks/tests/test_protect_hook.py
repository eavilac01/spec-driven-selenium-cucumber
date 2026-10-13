"""Batería de pruebas de protect-config-hook.sh.

Uso: python3 -I .claude/hooks/tests/test_protect_hook.py .claude/hooks/protect-config-hook.sh
Sale con 1 si algún caso no se comporta como se espera.
"""
import json
import subprocess
import sys

HOOK = sys.argv[1]
BLOCK, ALLOW = 2, 0

CASES = [
    # --- Escrituras: deben bloquearse ---
    (BLOCK, "echo x > .claude/agents/a.md"),
    (BLOCK, 'echo x > ".claude/agents/a.md"'),
    (BLOCK, "cat <<EOF > CLAUDE.md\nhola\nEOF"),
    (BLOCK, "printf x >> MEMORY.md"),
    (BLOCK, "echo x | tee .claude/rules/02-agent-permissions.md"),
    (BLOCK, "echo x | tee -a MEMORY.md"),
    (BLOCK, "sed -i 's/a/b/' .claude/agents/qa-test-verifier.md"),
    (BLOCK, "sed --in-place 's/a/b/' CLAUDE.md"),
    (BLOCK, "rm -rf .claude"),
    (BLOCK, "mv .claude/settings.json /tmp/x"),
    (BLOCK, "cp /tmp/x .claude/settings.json"),
    (BLOCK, "touch .claude/zz"),
    (BLOCK, "chmod -x .claude/hooks/devops-gate-hook.sh"),
    (BLOCK, "git checkout -- .claude/settings.json"),
    (BLOCK, "git restore MEMORY.md"),
    (BLOCK, "python3 -c \"open('.claude/settings.json','w').write('{}')\""),
    (BLOCK, "python3 - <<'EOF'\nopen('CLAUDE.md','w').write('x')\nEOF"),
    (BLOCK, "python3 -c \"import json;json.load(open('.claude/settings.json'))\""),  # conservador
    (BLOCK, "bash -c \"echo x > .claude/a\""),
    (BLOCK, "cd /tmp && echo y > /home/u/repo/.claude/agents/x.md"),
    (BLOCK, "echo ok; echo x > MEMORY.md"),
    # Huecos encontrados por el gate DevOps (a14acb2)
    (BLOCK, "git -C . checkout HEAD -- .claude"),
    (BLOCK, "git -c core.x=y restore CLAUDE.md"),
    (BLOCK, "cd .claude && echo x > settings.json"),
    (BLOCK, "cd .claude/agents; rm qa-test-verifier.md"),
    (BLOCK, "find .claude -name x -delete"),
    (BLOCK, "find .claude -name '*.md' -exec sed -i 's/a/b/' {} +"),
    (BLOCK, "echo x > .claude/devops-gate.json.bak"),
    (BLOCK, "echo x > .claude/devops-gate.jsonX"),
    # AGENTS.md: instrucciones para cualquier agente de código
    (BLOCK, "echo x >> AGENTS.md"),
    (BLOCK, "sed -i 's/a/b/' AGENTS.md"),
    (BLOCK, "git checkout -- AGENTS.md"),
    # .github/**: los workflows solo cambian con Edit/Write, bajo ask (decisión del usuario, 2026-10-13)
    (BLOCK, "echo x > .github/workflows/ci.yml"),
    (BLOCK, "sed -i 's/a/b/' .github/workflows/ci.yml"),
    (BLOCK, "python3 - <<'EOF'\nopen('.github/workflows/ci.yml','w').write('x')\nEOF"),
    (BLOCK, "python3 -c \"p='.github/workflows/ci.yml';open(p,'w').write('x')\""),
    (BLOCK, "cd .github && echo x > workflows/ci.yml"),
    (BLOCK, "git checkout -- .github/workflows/ci.yml"),
    (BLOCK, "rm -rf .github"),
    # La excepción de CHK-13 no tapa lo que se encadena ni un código distinto
    (BLOCK, "python3 -c \"import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]\" .github/workflows/*.yml; echo x > .github/workflows/ci.yml"),
    (BLOCK, "python3 -c \"import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]];open('.github/workflows/ci.yml','w')\" .github/workflows/*.yml"),
    (BLOCK, "python3 -c \"import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]\" .claude/settings.json && python3 -c \"open('.claude/x','w')\""),
    # --- Lecturas y operaciones legítimas: deben permitirse ---
    (ALLOW, "cat .claude/agents/qa-test-verifier.md"),
    (ALLOW, "git grep -n Thread -- .claude"),
    (ALLOW, "sed -n 1,5p CLAUDE.md"),
    (ALLOW, "wc -l MEMORY.md"),
    (ALLOW, "git diff -- .claude CLAUDE.md"),
    (ALLOW, "git add .claude MEMORY.md && git commit -q -m \"msg\""),
    (ALLOW, "git commit -F - <<'EOF'\nfix: ajuste en .claude/agents y MEMORY.md\nEOF"),
    (ALLOW, "python3 /opt/skill/scripts/validate_agents.py .claude/agents"),
    (ALLOW, "python3 -m json.tool .claude/settings.json"),
    (ALLOW, "cat > .claude/devops-gate.json <<EOF\n{}\nEOF"),
    (ALLOW, "printf '{}' > .claude/devops-gate.json"),
    (ALLOW, "./mvnw -B -ntp clean test -Dheadless=true 2>&1 | grep BUILD"),
    (ALLOW, "cat CLAUDE.md > /tmp/copy.md"),
    (ALLOW, "grep -c '^memory:' .claude/agents/qa-test-verifier.md"),
    (ALLOW, "git grep -n x -- .claude 2>/dev/null"),
    (ALLOW, "ls -l .claude/hooks/devops-gate-hook.sh"),
    (ALLOW, "git log --oneline -- MEMORY.md"),
    (ALLOW, "echo hola > /tmp/x.txt"),
    (ALLOW, "git push origin main"),
    # Contrapartes legítimas de los huecos cerrados
    (ALLOW, "git -C /repo log --oneline -- .claude"),
    (ALLOW, "cd .claude && ls -la"),
    (ALLOW, "find .claude -name '*.md'"),
    (ALLOW, "cat AGENTS.md"),
    (ALLOW, "cat > .claude/devops-gate.json <<'EOF'\n{\"verdict\": \"APROBADO\"}\nEOF"),
    # Contrapartes legítimas de .github/**
    (ALLOW, "python3 -c \"import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]\" .github/workflows/*.yml"),
    (ALLOW, "cat .github/workflows/ci.yml"),
    (ALLOW, "git diff -- .github Jenkinsfile"),
    (ALLOW, "git grep -n pipefail -- .github Jenkinsfile"),
    (BLOCK, "git grep -n tee -- .github Jenkinsfile"),  # conservador: un escritor como argumento bloquea
    (ALLOW, "git add .github/workflows/ci.yml && git commit -q -m \"ci: x\""),
    (ALLOW, "git show 3be5956 -- .github/workflows/ci.yml"),
    (ALLOW, "echo x > .githubx"),
    (ALLOW, "cd .github && ls workflows"),
]

fails = 0
for expected, cmd in CASES:
    payload = json.dumps({"tool_input": {"command": cmd}})
    rc = subprocess.run(["bash", HOOK], input=payload, text=True, capture_output=True).returncode
    ok = rc == expected
    fails += not ok
    label = "BLOQUEA" if expected == BLOCK else "PERMITE"
    print(f"{'OK ' if ok else 'FALLO'} [{label}] rc={rc}  {cmd.splitlines()[0][:70]}")
print(f"\n{len(CASES) - fails}/{len(CASES)} casos correctos")
sys.exit(1 if fails else 0)
