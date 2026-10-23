(*
    Control de nivel de tanque con dos bombas alternadas
    ----------------------------------------------------
    Caso típico de acueductos, edificios y plantas:
    - Sensor analógico 4-20 mA de nivel (0-100 %) y flotador de respaldo para alto-alto.
    - Arranca la bomba líder con nivel bajo y la detiene con nivel alto (histéresis).
    - Si el nivel sigue bajando con la líder en marcha, entra la segunda bomba.
    - Las bombas se alternan en cada ciclo para repartir el desgaste.
    - Si una bomba falla (sin confirmación de marcha), queda fuera y trabaja la otra.

    Lenguaje: Texto estructurado IEC 61131-3

    Autor: Juan Sebastián Ortiz Quintero
*)
FUNCTION_BLOCK FB_ControlNivel
VAR_INPUT
    NivelRaw        : INT;            (* IW64: 0..27648 en Siemens para 4..20 mA *)
    FlotadorAltoAlto: BOOL;           (* I0.0  NC: FALSE = rebose inminente *)
    ConfirmaB1      : BOOL;           (* I0.1  contacto auxiliar del contactor KM1 *)
    ConfirmaB2      : BOOL;           (* I0.2  contacto auxiliar del contactor KM2 *)
    Reset           : BOOL;           (* I0.3 *)
    Auto            : BOOL := TRUE;   (* selector manual / automático *)

    (* Este tanque se VACÍA con las bombas (pozo / cárcamo). Para llenado, invertir la lógica *)
    NivelArranque   : REAL := 70.0;   (* % arranca la bomba líder *)
    NivelParo       : REAL := 30.0;   (* % detiene todas *)
    NivelApoyo      : REAL := 85.0;   (* % arranca la segunda bomba *)
    NivelAlarmaAlta : REAL := 92.0;   (* % alarma *)
END_VAR
VAR_OUTPUT
    Bomba1, Bomba2  : BOOL;           (* Q0.0, Q0.1 *)
    Alarma          : BOOL;           (* Q0.2 sirena / piloto *)
    NivelPct        : REAL;
    FallaB1, FallaB2: BOOL;
    Lider           : INT := 1;       (* bomba que arranca primero en este ciclo *)
    SensorFalla     : BOOL;
END_VAR
VAR
    demanda         : BOOL;
    apoyo           : BOOL;
    tonConf1        : TON;
    tonConf2        : TON;
    ftDemanda       : F_TRIG;
END_VAR

(* 1. Escalado de la señal analógica y diagnóstico del lazo 4-20 mA *)
NivelPct := INT_TO_REAL(NivelRaw) * 100.0 / 27648.0;
SensorFalla := (NivelRaw < -500) OR (NivelRaw > 32000);   (* cable roto o cortocircuito *)
IF SensorFalla THEN
    NivelPct := 100.0;               (* con sensor dañado se asume tanque lleno: es el caso seguro *)
END_IF;

(* 2. Demanda con histéresis *)
IF NivelPct >= NivelArranque OR NOT FlotadorAltoAlto THEN
    demanda := TRUE;
ELSIF NivelPct <= NivelParo THEN
    demanda := FALSE;
END_IF;

IF NivelPct >= NivelApoyo OR NOT FlotadorAltoAlto THEN
    apoyo := TRUE;
ELSIF NivelPct <= NivelArranque THEN
    apoyo := FALSE;
END_IF;

(* 3. Alternancia: al terminar cada ciclo de bombeo cambia la bomba líder *)
ftDemanda(CLK := demanda);
IF ftDemanda.Q THEN
    IF Lider = 1 THEN Lider := 2; ELSE Lider := 1; END_IF;
END_IF;

(* 4. Supervisión: si se ordena marcha y no llega confirmación en 3 s, falla *)
tonConf1(IN := Bomba1 AND NOT ConfirmaB1, PT := T#3S);
tonConf2(IN := Bomba2 AND NOT ConfirmaB2, PT := T#3S);
IF tonConf1.Q THEN FallaB1 := TRUE; END_IF;
IF tonConf2.Q THEN FallaB2 := TRUE; END_IF;
IF Reset THEN
    FallaB1 := FALSE;
    FallaB2 := FALSE;
END_IF;

(* 5. Asignación de bombas *)
IF NOT Auto THEN
    Bomba1 := FALSE;
    Bomba2 := FALSE;
ELSE
    IF Lider = 1 THEN
        Bomba1 := demanda AND NOT FallaB1;
        Bomba2 := (apoyo OR (demanda AND FallaB1)) AND NOT FallaB2;
    ELSE
        Bomba2 := demanda AND NOT FallaB2;
        Bomba1 := (apoyo OR (demanda AND FallaB2)) AND NOT FallaB1;
    END_IF;
END_IF;

(* 6. Alarma *)
Alarma := NivelPct >= NivelAlarmaAlta
          OR NOT FlotadorAltoAlto
          OR FallaB1 OR FallaB2
          OR SensorFalla;
END_FUNCTION_BLOCK
