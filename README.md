# Havoc — Laboratorio defensivo de CTI para el aula

> [!CAUTION]
> **Uso autorizado únicamente en el aula.** Este repositorio solo puede utilizarse en ejercicios dirigidos por un instructor sobre inteligencia de amenazas (CTI), ingeniería de detección, respuesta ante incidentes y análisis de malware, y exclusivamente en las máquinas virtuales de laboratorio identificadas de forma expresa. Cualquier uso fuera del alcance escrito de la clase —incluidos sistemas de producción, redes públicas, sistemas de terceros o dispositivos sin permiso explícito de su propietario— queda prohibido y no está autorizado por el instructor ni por el responsable del repositorio.

> [!WARNING]
> Havoc es un framework de mando y control que contiene funciones de posexplotación, inyección de procesos, manipulación de tokens y evasión de defensas. Todos los artefactos generados deben tratarse como malware. No los subas a servicios públicos de análisis, no los copies a dispositivos personales y no expongas el Teamserver ni ningún listener a Internet.

Este fork está destinado a enseñar cómo reconocer, investigar y documentar actividad de mando y control en Windows mediante un SIEM, Microsoft Defender, Sysmon, los registros de eventos de Windows, telemetría de red y herramientas forenses. No es una guía para realizar operaciones fuera de un laboratorio aislado y autorizado.

<div align="center">
  <img width="125px" src="assets/Havoc.png" />
  <h1>Havoc</h1>
  <p><i>Havoc fue creado originalmente por <a href="https://twitter.com/C5pider">@C5pider</a>. Este fork añade documentación y controles para su uso defensivo en el aula.</i></p>
  <img src="assets/Screenshots/FullSessionGraph.jpeg" width="90%" /><br />
  <img src="assets/Screenshots/MultiUserAgentControl.png" width="90%" /><br />
</div>

## Alcance y autorización

Antes de comenzar, el instructor debe documentar:

- Los instructores y alumnos autorizados.
- Las máquinas virtuales exactas de Kali, Windows y SIEM incluidas en el ejercicio.
- La fecha y las horas de inicio y finalización.
- La subred host-only de VMware y los puertos permitidos.
- Las acciones permitidas y las expresamente prohibidas.
- El procedimiento de conservación, acceso y eliminación de evidencias.
- El mecanismo para detener inmediatamente el ejercicio si se supera el alcance.

Queda prohibido:

- Usar adaptadores en modo puente, listeners expuestos a Internet, reenvío de puertos o destinos públicos o en la nube.
- Actuar contra cualquier sistema no incluido expresamente en la autorización escrita.
- Introducir credenciales reales, datos personales o información de producción en el laboratorio.
- Realizar volcado de credenciales, robo de tokens, persistencia, movimiento lateral, escalada de privilegios o recogida de datos.
- Desactivar o eludir Defender, AMSI, ETW, EDR, Sysmon, el registro de eventos u otros controles de seguridad.
- Distribuir artefactos mediante correo, sitios web, unidades compartidas, dispositivos extraíbles o servicios de terceros.

La autorización debe proceder del propietario del sistema. Este aviso no sustituye el consentimiento ni la legislación aplicable.

## Arquitectura del laboratorio

Utiliza al menos dos máquinas virtuales aisladas y, preferiblemente, una tercera máquina para el SIEM:

```text
Red host-only de VMware — sin puente y sin reenvío de puertos

VM Kali del instructor             VM Windows 11 del alumno
Teamserver + cliente               Defender + Sysmon + agente SIEM
TCP 40056: administración          Usuarios y datos sintéticos
TCP 8443: listener del aula
             \                    /
              \                  /
                   VM SIEM opcional
```

Controles recomendados:

- Usa exclusivamente una red **host-only** de VMware.
- Desactiva carpetas compartidas, arrastrar y soltar y el portapapeles compartido mientras se manipulen artefactos.
- Crea instantáneas limpias antes de cada clase.
- Mantén activos los cortafuegos y los controles de seguridad de Windows.
- Utiliza un puerto no privilegiado, como `8443`, para el listener.
- Revierte Windows a una instantánea limpia después de cada ejercicio.
- No configures NAT, bridge, routing ni port forwarding para la red del laboratorio.

## Red obligatoria del aula

El script de preparación acepta únicamente direcciones pertenecientes a:

```text
22.44.77.0/24
```

Esto comprende las direcciones utilizables `22.44.77.1` a `22.44.77.254`.

> [!IMPORTANT]
> `22.44.77.0/24` es espacio de direccionamiento público, no una subred privada RFC1918. Debe permanecer estrictamente aislada dentro de una red host-only de VMware, sin puente, NAT, reenvío ni ruta hacia redes externas.

Comprueba la interfaz de Kali antes de empezar:

```bash
ip -br -4 addr
ip -4 route
```

## Requisitos de Kali

Este checkout presupone:

- Repositorio en `~/Havoc` o en otro directorio controlado por el instructor.
- Ejecutables `havoc` y `client/Havoc`.
- `nasm` y los compiladores MinGW incluidos dentro de `data/`.
- Una dirección `22.44.77.*` asignada a la interfaz host-only.

Validación básica:

```bash
cd ~/Havoc
./havoc --help
test -x data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc
test -x data/i686-w64-mingw32-cross/bin/i686-w64-mingw32-gcc
```

Las direcciones asignadas por VMware pueden cambiar tras reiniciar o restaurar una instantánea. Verifica siempre la dirección antes de configurar el listener.

## Requisitos de telemetría en Windows 11

Mantén activos los controles de seguridad y recoge, como mínimo:

- Eventos operativos de Microsoft Defender Antivirus.
- Registro de Seguridad de Windows, incluida la creación de procesos cuando esté configurada.
- Registros operativos de PowerShell y Script Block Logging.
- Eventos de Sysmon para procesos, conexiones de red, carga de imágenes, acceso a procesos, ficheros, registro y DNS según una configuración revisada por el instructor.
- Eventos de estado del agente del SIEM o del reenviador de registros.

Referencias oficiales:

- [Microsoft Sysmon](https://learn.microsoft.com/sysinternals/downloads/sysmon)
- [Registro de PowerShell en Windows](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_logging_windows)
- [Auditoría de seguridad de Windows](https://learn.microsoft.com/windows/security/threat-protection/auditing/advanced-security-auditing-faq)
- [Eventos de Microsoft Defender Antivirus](https://learn.microsoft.com/defender-endpoint/troubleshoot-microsoft-defender-antivirus)

No instales sin revisar una configuración de Sysmon obtenida de Internet. Evalúa primero su cobertura, impacto sobre la privacidad y volumen esperado.

Comprueba los sensores desde una consola elevada de PowerShell:

```powershell
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled
Get-Service Sysmon64 -ErrorAction SilentlyContinue
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 5
Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' -MaxEvents 5
auditpol.exe /get /subcategory:'Process Creation'
```

Resuelve cualquier sensor inactivo o registro ausente antes de iniciar la simulación.

## Requisitos del SIEM

El laboratorio es independiente del SIEM. Puede utilizarse Microsoft Sentinel, Splunk, Elastic, Security Onion u otra plataforma aprobada. Antes del ejercicio, verifica la recepción de:

- Eventos de Seguridad de Windows.
- `Microsoft-Windows-Sysmon/Operational`.
- `Microsoft-Windows-PowerShell/Operational`.
- Eventos operativos de Microsoft Defender.
- Metadatos DNS, de cortafuegos, proxy o red para el segmento host-only, si están disponibles.

Registra la latencia normal de ingesta para que un retraso no se confunda con una detección fallida.

## Preparación automática protegida

El repositorio incluye [scripts/setup-classroom-lab.sh](scripts/setup-classroom-lab.sh). El script:

- Rechaza la ejecución como `root`.
- Solo acepta una interfaz con dirección `22.44.77.*`.
- Advierte si la interfaz también contiene la ruta predeterminada.
- Verifica binarios, herramientas y compiladores incluidos.
- Genera credenciales únicas.
- Crea un perfil privado específico para el aula.
- Protege credenciales, claves, base de datos y evidencias mediante permisos restrictivos.
- Puede respaldar el estado anterior.
- Puede iniciar el Teamserver al finalizar.
- No crea listeners ni agentes y no automatiza entrega, evasión o posexplotación.

Uso:

```bash
cd ~/Havoc
./scripts/setup-classroom-lab.sh \
  --accept-classroom-policy \
  --interface eth0 \
  --fresh-state \
  --start-server
```

Sustituye `eth0` si la dirección `22.44.77.*` pertenece a otra interfaz.

El script genera:

- Perfil: `profiles/classroom.generated.yaotl`.
- Credenciales: `data/classroom-credentials.txt`.
- Copias de seguridad: `data/classroom-backups/`.

El perfil generado y el directorio `data/` están excluidos de Git. No publiques las credenciales ni las evidencias.

## Preparación manual

### 1. Permisos

Ejecuta Havoc con la cuenta normal del laboratorio. No uses `sudo`, porque crearía bases de datos y evidencias propiedad de `root`.

```bash
cd ~/Havoc
chmod 700 data/loot
chmod 600 data/server.key data/teamserver.db
chmod 644 data/server.cert
chmod 600 profiles/havoc.yaotl data/havoc.yaotl
```

Si ya existen archivos propiedad de `root`, un administrador debe devolver únicamente esos archivos a la cuenta del laboratorio. No uses `chmod -R 777`.

### 2. Perfil del aula

Revisa `profiles/havoc.yaotl`:

- Sustituye todas las contraseñas de ejemplo.
- Mantén la administración del Teamserver en el puerto privado `40056`, salvo que el diseño indique otro.
- Guarda las credenciales en el almacén aprobado por el instructor.
- Confirma que el perfil utiliza los compiladores incluidos bajo `data/`.

No confirmes en Git contraseñas, claves privadas, bases de datos, evidencias ni artefactos generados.

### 3. Teamserver

Havoc resuelve perfiles, bases de datos, payloads y registros a partir del directorio de trabajo. Inícialo siempre desde la raíz:

```bash
cd ~/Havoc
./havoc server --profile profiles/havoc.yaotl --verbose
```

La salida esperada incluye:

```text
Starting Teamserver on wss://0.0.0.0:40056
Teamserver logs saved under: data/loot/...
```

No utilices `./havoc server -d` en este checkout. Esa opción carga `data/havoc.yaotl` y puede seleccionar una versión incompatible del compilador MinGW del sistema.

### 4. Cliente

En otra terminal:

```bash
cd ~/Havoc
./havoc client
```

Crea una conexión nueva con:

- Host: `127.0.0.1` si el cliente se ejecuta en la misma VM Kali.
- Puerto: `40056`.
- Usuario y contraseña: los valores del perfil utilizado por el Teamserver.

El cliente rellena inicialmente una contraseña de ejemplo, `password`, que no se sincroniza con el perfil. Sustitúyela. No continúes hasta que el Teamserver indique que el operador se ha autenticado correctamente.

### 5. Listener aislado

Desde un cliente autenticado, crea un listener con un nombre único:

- Bind host: la dirección actual `22.44.77.*` de Kali.
- Bind port: `8443` u otro puerto no privilegiado aprobado.
- Connection host: la misma dirección host-only.
- Connection port: el mismo puerto aprobado.
- No uses una dirección pública externa, puenteada, reenviada o de producción.

Comprueba los puertos locales:

```bash
ss -ltnp | rg ':40056|:8443'
```

Este README no documenta generación o entrega de agentes, acceso a credenciales, persistencia, evasión ni posexplotación. Cualquier artefacto gestionado por el instructor debe permanecer dentro del laboratorio y ajustarse al plan escrito.

## Flujo de la clase defensiva

### Fase 1: establecer una línea base

Recoge al menos diez minutos de actividad normal de Windows. Identifica:

- Relaciones habituales entre procesos padre e hijo.
- Resolutores DNS y destinos de red esperados.
- Uso normal de PowerShell y del intérprete de comandos.
- Volumen habitual de Defender y Sysmon.
- Latencia de ingesta e identificadores del host en el SIEM.

### Fase 2: observar la actividad autorizada

Solo el instructor realiza la simulación aprobada. Los alumnos observan la telemetría.

| Fuente | Eventos o comportamientos que revisar |
| --- | --- |
| Sysmon | Creación de procesos (1), conexiones de red (3), carga de imágenes (7), hilos remotos (8), acceso a procesos (10), creación de ficheros (11), registro (12–14) y DNS (22) |
| Seguridad de Windows | Creación de procesos (4688), inicios de sesión (4624/4625), credenciales explícitas (4648) e instalación de servicios (4697), cuando la auditoría esté habilitada |
| PowerShell | Eventos del motor y del proveedor, además de Script Block Logging, como 4104 |
| Defender | Detección, corrección, cambios de configuración y estado |
| Red | Conexiones repetidas, destinos TLS anómalos, puertos inesperados y periodicidad |

No todos los eventos aparecen en todos los equipos. Valida la política de auditoría y los sensores antes de concluir que falta telemetría.

### Fase 3: crear detecciones basadas en comportamiento

Objetivos recomendados:

- Detectar un proceso inusual con conexiones salientes recurrentes.
- Identificar relaciones padre/hijo inesperadas.
- Alertar del acceso a otro proceso con derechos asociados a inspección de memoria o inyección.
- Localizar módulos no firmados o anómalos cargados en procesos de confianza.
- Detectar PowerShell o shells cuyo uso se aparte de la línea base.
- Correlacionar eventos de red, procesos y Defender o Sysmon en el mismo host.

Cada detección debe documentar:

- Fuente y campos necesarios.
- Política de auditoría requerida.
- Lógica de consulta.
- Posibles falsos positivos.
- Severidad.
- Acción de respuesta.
- Evidencia de validación.

### Fase 4: investigar e informar

El informe del alumno debe incluir:

1. El primer evento relevante.
2. El árbol de procesos y las líneas de comandos.
3. Usuario, nivel de integridad, hashes, firmas y rutas disponibles.
4. Destinos y tiempos de red.
5. Corroboración entre Defender, Sysmon y SIEM.
6. Separación clara entre hechos observados e hipótesis.
7. Recomendaciones de contención y recuperación.

No envíes artefactos, claves privadas, credenciales ni volcados de memoria a servicios públicos.

## Solución de problemas

### Se restaura un listener con una IP antigua

Los listeners se guardan en `data/teamserver.db`. Elimina o edita el listener obsoleto desde un cliente autenticado y vuelve a crearlo con la dirección `22.44.77.*` actual.

Para empezar una clase sin conservar el estado anterior, detén el Teamserver y crea una copia recuperable:

```bash
mv data/teamserver.db data/teamserver.db.previous-class
```

Al reiniciar se creará una base de datos limpia.

### El cliente no se autentica

- Confirma que el cliente y el servidor utilizan las credenciales del mismo perfil.
- Las credenciales distinguen mayúsculas y minúsculas.
- Sustituye la contraseña de ejemplo del cliente.
- No administres listeners hasta ver el mensaje de autenticación correcta.

### `bind: cannot assign requested address`

La dirección configurada no pertenece actualmente a Kali. Compruébala con:

```bash
ip -br -4 addr
```

Selecciona la dirección `22.44.77.*` vigente. No resuelvas el problema exponiendo el listener mediante puente o reenvío.

### El puerto 40056 ya está ocupado

Localiza el proceso antes de iniciar otra instancia:

```bash
ss -ltnp | rg ':40056'
pgrep -af 'havoc server'
```

Detén de forma ordenada la instancia anterior. No ejecutes varios Teamservers contra la misma base de datos.

### Permisos o registros propiedad de root

Deja de iniciar el servidor con `sudo`. Devuelve la propiedad únicamente a los ficheros afectados y restringe el acceso a la base de datos, los perfiles, la clave privada y las evidencias.

### Errores de compilación con `__stosb`, punteros o `SysInvoke`

El checkout y la versión MinGW del sistema pueden ser incompatibles. Usa el perfil explícito del aula y los compiladores incluidos. No ocultes de forma general los diagnósticos ni copies binarios parcheados desde fuentes no fiables.

### Aviso de Python `invalid escape sequence`

Algunos módulos opcionales utilizan sintaxis antigua de cadenas de Python. El aviso no está relacionado con la autenticación ni con el listener. Desactiva módulos innecesarios en lugar de debilitar la seguridad del sistema.

## Limpieza después de cada clase

1. Detén el cliente y el Teamserver.
2. Confirma que los puertos `40056` y `8443` están cerrados.
3. Exporta únicamente los registros autorizados.
4. Guarda las evidencias en la ubicación aprobada, con control de acceso y fecha de eliminación.
5. Elimina o rota las credenciales temporales.
6. Revierte Windows y las máquinas que manipularon artefactos a instantáneas limpias.
7. Confirma que los adaptadores de VMware siguen siendo host-only y que no existen reglas de reenvío.
8. Elimina los artefactos cuando termine el periodo de conservación.

## Lista de comprobación del instructor

- [ ] La autorización identifica participantes, VMs, subred, acciones y horario.
- [ ] Existen instantáneas limpias y se han probado.
- [ ] La red es host-only y no tiene bridge, NAT ni port forwarding.
- [ ] Defender y los registros necesarios permanecen activos.
- [ ] Sysmon y el agente SIEM están sanos.
- [ ] Los eventos de prueba llegan al SIEM antes de la clase.
- [ ] Se han sustituido las contraseñas de ejemplo.
- [ ] Havoc se ejecuta con una cuenta sin privilegios.
- [ ] Solo se utiliza la subred `22.44.77.0/24`.
- [ ] El listener utiliza únicamente la dirección host-only y el puerto aprobado.
- [ ] Los alumnos conocen las reglas de evidencias y limpieza.
- [ ] El instructor puede detener inmediatamente el ejercicio.

## Componentes del proyecto

### Cliente

Interfaz gráfica multiplataforma escrita en C++ y Qt.

### Teamserver

Servidor escrito en Go que coordina el cliente, el estado del laboratorio y los listeners autorizados.

### Demon

Agente original de Havoc escrito en C y ensamblador. Contiene capacidades de alto riesgo y debe tratarse como malware dentro del laboratorio.

## Atribución

Havoc fue creado por [C5pider](https://twitter.com/C5pider). Consulta la licencia y los avisos del proyecto original para conocer los términos aplicables. Esta documentación añade controles para el aula; no concede permiso para utilizar sistemas que no sean propios o que no estén administrados con autorización expresa.
