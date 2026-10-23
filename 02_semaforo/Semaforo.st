(*
    Semáforo de dos vías con modo nocturno y botón peatonal
    --------------------------------------------------------
    Máquina de estados con CASE, el patrón que uso para cualquier secuencia:
    cada estado tiene un tiempo, unas salidas y una condición de salida.

    Lenguaje: Texto estructurado IEC 61131-3

    Autor: Juan Sebastián Ortiz Quintero
*)
TYPE E_Semaforo :
(
    VERDE_A      := 0,
    AMARILLO_A   := 1,
    TODO_ROJO_1  := 2,
    VERDE_B      := 3,
    AMARILLO_B   := 4,
    TODO_ROJO_2  := 5,
    PEATONAL     := 6,
    NOCTURNO     := 7
);
END_TYPE

FUNCTION_BLOCK FB_Semaforo
VAR_INPUT
    Habilitar      : BOOL;                 (* I0.0 selector de encendido *)
    ModoNocturno   : BOOL;                 (* I0.1 selector o reloj *)
    BotonPeatonal  : BOOL;                 (* I0.2 pulsador NA *)
    tVerdeA        : TIME := T#30S;
    tVerdeB        : TIME := T#20S;
    tAmarillo      : TIME := T#4S;
    tTodoRojo      : TIME := T#2S;
    tPeatonal      : TIME := T#15S;
END_VAR
VAR_OUTPUT
    RojoA, AmarilloA, VerdeA : BOOL;       (* Q0.0 .. Q0.2 *)
    RojoB, AmarilloB, VerdeB : BOOL;       (* Q0.3 .. Q0.5 *)
    PeatonVerde, PeatonRojo  : BOOL;       (* Q0.6, Q0.7 *)
    EstadoActual             : E_Semaforo;
END_VAR
VAR
    estado        : E_Semaforo := TODO_ROJO_2;
    tonEstado     : TON;
    tiempo        : TIME;
    solicitud     : BOOL;                  (* memoria del botón peatonal *)
    tonParpadeo   : TON;
    parpadeo      : BOOL;
END_VAR

(* Memoriza la solicitud peatonal hasta atenderla *)
IF BotonPeatonal THEN
    solicitud := TRUE;
END_IF;

(* Base de tiempo para intermitencia (1 Hz) *)
tonParpadeo(IN := NOT tonParpadeo.Q, PT := T#500MS);
IF tonParpadeo.Q THEN
    parpadeo := NOT parpadeo;
END_IF;

IF NOT Habilitar THEN
    estado := TODO_ROJO_2;
ELSIF ModoNocturno AND estado <> NOCTURNO THEN
    estado := NOCTURNO;
END_IF;

(* Tiempo del estado actual *)
CASE estado OF
    VERDE_A:                   tiempo := tVerdeA;
    VERDE_B:                   tiempo := tVerdeB;
    AMARILLO_A, AMARILLO_B:    tiempo := tAmarillo;
    TODO_ROJO_1, TODO_ROJO_2:  tiempo := tTodoRojo;
    PEATONAL:                  tiempo := tPeatonal;
ELSE                           tiempo := T#0S;
END_CASE;

tonEstado(IN := Habilitar AND estado <> NOCTURNO, PT := tiempo);

(* Transiciones *)
IF tonEstado.Q THEN
    tonEstado(IN := FALSE);                (* reinicia el temporizador para el siguiente estado *)
    CASE estado OF
        VERDE_A:      estado := AMARILLO_A;
        AMARILLO_A:   estado := TODO_ROJO_1;
        TODO_ROJO_1:
            IF solicitud THEN
                estado := PEATONAL;
            ELSE
                estado := VERDE_B;
            END_IF;
        PEATONAL:     solicitud := FALSE;  estado := VERDE_B;
        VERDE_B:      estado := AMARILLO_B;
        AMARILLO_B:   estado := TODO_ROJO_2;
        TODO_ROJO_2:  estado := VERDE_A;
    END_CASE;
END_IF;

IF estado = NOCTURNO AND NOT ModoNocturno THEN
    estado := TODO_ROJO_2;                 (* sale de noche siempre por todo rojo *)
END_IF;

(* Salidas: cada estado define todas las luces, nunca hay dos verdes a la vez *)
VerdeA    := estado = VERDE_A;
AmarilloA := estado = AMARILLO_A OR (estado = NOCTURNO AND parpadeo);
RojoA     := NOT (VerdeA OR AmarilloA) AND estado <> NOCTURNO;

VerdeB    := estado = VERDE_B;
AmarilloB := estado = AMARILLO_B;
RojoB     := (NOT (VerdeB OR AmarilloB) AND estado <> NOCTURNO) OR (estado = NOCTURNO AND parpadeo);

PeatonVerde := estado = PEATONAL;
PeatonRojo  := NOT PeatonVerde AND Habilitar;

EstadoActual := estado;
END_FUNCTION_BLOCK
