(*
    Arranque y paro de motor con enclavamiento, protección térmica y alarma
    ------------------------------------------------------------------------
    Lenguaje: Texto estructurado IEC 61131-3 (TIA Portal SCL, CODESYS y compatibles)

    El pulsador de paro y el relé térmico se cablean NORMALMENTE CERRADOS:
    si un cable se corta, el motor se detiene (falla segura).

    Autor: Juan Sebastián Ortiz Quintero
*)
FUNCTION_BLOCK FB_ArranqueParo
VAR_INPUT
    Arranque      : BOOL;          (* I0.0  pulsador NA *)
    Paro          : BOOL;          (* I0.1  pulsador NC: TRUE = no presionado *)
    TermicoOK     : BOOL;          (* I0.2  contacto NC del relé térmico: TRUE = sin disparo *)
    Reset         : BOOL;          (* I0.3  pulsador NA de rearme de alarma *)
    TiempoAlarma  : TIME := T#5S;  (* tiempo con térmico disparado antes de bloquear *)
END_VAR
VAR_OUTPUT
    Motor         : BOOL;          (* Q0.0  contactor KM1 *)
    PilotoMarcha  : BOOL;          (* Q0.1  piloto verde *)
    PilotoFalla   : BOOL;          (* Q0.2  piloto rojo, intermitente con falla activa *)
    Bloqueado     : BOOL;          (* falla enclavada hasta Reset *)
    Horas         : REAL;          (* horómetro para mantenimiento *)
END_VAR
VAR
    tonTermico    : TON;
    rtArranque    : R_TRIG;
    tonParpadeo   : TON;
    parpadeo      : BOOL;
    tonHora       : TON;
END_VAR

(* 1. Detección de falla térmica: si dura más que TiempoAlarma se enclava *)
tonTermico(IN := NOT TermicoOK, PT := TiempoAlarma);
IF tonTermico.Q THEN
    Bloqueado := TRUE;
END_IF;

(* El rearme solo procede cuando el térmico ya se restableció *)
IF Reset AND TermicoOK THEN
    Bloqueado := FALSE;
END_IF;

(* 2. Arranque por flanco: mantener presionado el botón no rearranca tras una falla *)
rtArranque(CLK := Arranque);

IF NOT Paro OR NOT TermicoOK OR Bloqueado THEN
    Motor := FALSE;                         (* el paro siempre tiene prioridad *)
ELSIF rtArranque.Q THEN
    Motor := TRUE;                          (* enclavamiento: queda en marcha *)
END_IF;

(* 3. Pilotos *)
tonParpadeo(IN := NOT tonParpadeo.Q, PT := T#500MS);
IF tonParpadeo.Q THEN
    parpadeo := NOT parpadeo;
END_IF;

PilotoMarcha := Motor;
PilotoFalla  := (Bloqueado OR NOT TermicoOK) AND parpadeo;

(* 4. Horómetro: suma una centésima de hora cada 36 s de marcha *)
tonHora(IN := Motor AND NOT tonHora.Q, PT := T#36S);
IF tonHora.Q THEN
    Horas := Horas + 0.01;
END_IF;
END_FUNCTION_BLOCK
