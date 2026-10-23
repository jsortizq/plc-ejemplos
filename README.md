# Ejemplos de programación de PLC (IEC 61131‑3)

Tres programas de control industrial en **texto estructurado (ST)**, escritos como bloques de función reutilizables. Cada uno resuelve un caso real que aparece una y otra vez en planta, con las protecciones que en la práctica hacen la diferencia: falla segura, enclavamientos, supervisión de contactores y diagnóstico de sensores.

El código es estándar IEC 61131‑3, así que se puede llevar a **Siemens TIA Portal (SCL)**, **CODESYS**, **Schneider EcoStruxure Machine Expert**, **Beckhoff TwinCAT** y similares con cambios mínimos de direccionamiento.

| Ejemplo | Qué muestra |
|---|---|
| [01 Arranque y paro de motor](01_arranque_paro_motor/) | Enclavamiento, paro prioritario, relé térmico con alarma enclavada, arranque por flanco, horómetro |
| [02 Semáforo](02_semaforo/) | Máquina de estados con `CASE`, temporizadores por estado, solicitud peatonal memorizada, modo nocturno intermitente |
| [03 Control de nivel con dos bombas](03_control_nivel_bombas/) | Escalado 4‑20 mA, histéresis, alternancia de bombas, bomba de apoyo, supervisión por contacto auxiliar, falla de sensor |

---

## 01 · Arranque y paro de motor

**Tabla de E/S**

| Dirección | Señal | Tipo | Nota |
|---|---|---|---|
| I0.0 | Arranque | NA | |
| I0.1 | Paro | **NC** | TRUE = no presionado |
| I0.2 | Térmico OK | **NC** | TRUE = sin disparo |
| I0.3 | Reset alarma | NA | |
| Q0.0 | Contactor KM1 | | |
| Q0.1 | Piloto verde (marcha) | | |
| Q0.2 | Piloto rojo (falla) | | Intermitente |

**Decisiones de diseño**

- **Paro y térmico normalmente cerrados**: si se corta un cable, el PLC lo ve como "paro" y el motor se detiene. Con contactos NA un cable roto dejaría el motor sin forma de pararlo.
- **Arranque por flanco**: si el operario deja presionado el botón mientras se resetea una falla, el motor no arranca solo.
- **Alarma enclavada**: si el térmico dura disparado más de 5 s, queda bloqueado hasta que alguien lo rearme a propósito.

---

## 02 · Semáforo de dos vías

```
VERDE_A ──30s──▶ AMARILLO_A ──4s──▶ TODO_ROJO_1 ──2s──┬──▶ VERDE_B ──20s──▶ AMARILLO_B ──4s──▶ TODO_ROJO_2 ──2s──▶ VERDE_A
                                                       │
                                     (si hubo botón)   └──▶ PEATONAL ──15s──▶ VERDE_B
```

- Todos los tiempos son entradas del bloque: se ajustan desde la HMI sin tocar el programa.
- El botón peatonal se **memoriza**; se atiende en el siguiente "todo rojo", no corta un verde a la mitad.
- Las salidas se calculan a partir del estado, nunca se "encienden" sueltas: así es imposible tener dos verdes a la vez.
- En modo nocturno, amarillo intermitente en la vía principal y rojo intermitente en la secundaria.

---

## 03 · Control de nivel con dos bombas alternadas

Tanque o cárcamo que se vacía con bombas (aguas lluvias, aguas residuales, sumidero de planta).

| Dirección | Señal | Tipo |
|---|---|---|
| IW64 | Nivel 4‑20 mA (0‑100 %) | Analógica |
| I0.0 | Flotador alto‑alto | **NC** |
| I0.1 | Confirmación marcha bomba 1 (aux. KM1) | NA |
| I0.2 | Confirmación marcha bomba 2 (aux. KM2) | NA |
| I0.3 | Reset fallas | NA |
| Q0.0 / Q0.1 | Contactores bomba 1 / 2 | |
| Q0.2 | Alarma | |

| Nivel | Acción |
|---|---|
| ≥ 70 % | Arranca la bomba líder |
| ≥ 85 % | Arranca también la de apoyo |
| ≥ 92 % o flotador | Alarma |
| ≤ 30 % | Paran ambas y la líder cambia para el siguiente ciclo |

- **Histéresis** entre arranque y paro para no encender y apagar la bomba cada pocos segundos.
- **Alternancia** en cada ciclo: las dos bombas se desgastan igual y ninguna se queda pegada por falta de uso.
- **Supervisión**: si se manda a arrancar una bomba y su contactor no confirma en 3 s, se marca en falla y entra la otra.
- **Sensor dañado**: si la señal sale del rango del módulo (cable roto o en corto), el programa asume tanque lleno y arranca las bombas. El flotador alto‑alto es una segunda capa independiente del sensor.

---

## Uso

1. Cree un proyecto en su software de PLC.
2. Importe el `.st` como bloque de función (en TIA Portal: *Fuentes externas → Generar bloques*).
3. Llame el bloque desde el ciclo principal (`OB1` o `PLC_PRG`) y conecte las E/S según la tabla.

Antes de usarlos en un equipo real, valide el programa en simulación (PLCSIM, CODESYS SoftPLC) y haga las pruebas en sitio con el tablero sin carga.

---
Juan Sebastián Ortiz Quintero · Ingeniero en Mecatrónica · [Industrias Ortiz](https://jsortizq.github.io)
