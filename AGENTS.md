# Instrucciones para agentes

Instrucciones para colaboradores de IA y humanos que usan herramientas como **Cursor** y **Claude** en este repositorio.

## Commits y ramas de git: se requiere aprobación explícita del usuario

**Nunca hagas commit de cambios a git a menos que el usuario te lo pida explícitamente.** Realiza todos los cambios de código y luego espera a que el usuario solicite un commit antes de ejecutar cualquier comando `git commit`. Proponer un mensaje de commit está bien; ejecutarlo no.

**Nunca crees una rama de git a menos que el usuario te lo pida explícitamente.** No ejecutes `git branch` ni `git checkout -b` (o equivalente) por iniciativa propia, ni siquiera en preparación para un commit o Merge Request.

## Merge Requests: usa la plantilla del proyecto

Al crear un Merge Request (MR), completa siempre la descripción usando la plantilla en [`.gitlab/merge_request_templates/default.md`](.gitlab/merge_request_templates/default.md). Lee ese archivo y reemplaza cada comentario `<!-- … -->` con contenido concreto y relevante basado en los cambios reales. No dejes comentarios de marcador de posición en la descripción final.

## Commits: Conventional Commits (obligatorio)

Todo mensaje de commit **debe** seguir [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

### Formato

```
<type>[optional scope]: <short description>

[optional body]

[optional footer(s)]
```

- **Descripción:** modo imperativo, inicio en minúscula (el punto final no es obligatorio, pero mantén la consistencia).
- **Longitud máxima del encabezado:** mantén la primera línea en ≤ **72** caracteres cuando sea posible.

### Tipos permitidos (comunes)

Usa uno de: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

- **`feat`:** nuevo comportamiento o capacidad para los usuarios.
- **`fix`:** una corrección de error.
- **`docs`:** solo documentación.
- **`chore`:** mantenimiento que no es una funcionalidad o corrección de cara al usuario (dependencias, configuración, herramientas).
- **`ci`:** solo pipeline de CI/CD o automatización.

### Scope (opcional)

Un sustantivo entre paréntesis después del tipo, ej. `fix(postgres): handle null connection string`.

### Cambios incompatibles (breaking changes)

Cualquiera de las dos opciones:

- agrega **`!`** después del tipo/scope: `feat(api)!: remove legacy endpoint`, o
- agrega un footer: `BREAKING CHANGE: <qué cambió y qué hacer>`.

### Ejemplos (válidos)

- `feat(examples): add from-code compose sample`
- `fix(ci): use non-tls dind for self-hosted runners`
- `docs: clarify WAL-G vs backup-push in readme`
- `chore: bump gitlab-ci docker image tags`

### Ejemplos (inválidos — no usar)

- `Update dockerfile` (sin tipo)
- `Fixed bug` (no es conventional)
- `WIP` / `misc changes`

Al proponer o crear commits, **siempre** usa este formato. Si existen múltiples cambios no relacionados, **divídelos en varios commits** en lugar de un mensaje vago.
