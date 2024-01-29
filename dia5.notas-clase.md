-- Me gustaría saber las 5 formas de envío más usadas... y cuantas ventas se han mandado según esas formas de envío
-- CAMPO: ws_ship_mode_sk

    SELECT 
        ws_ship_mode_sk,
        count(*) as recuento
    FROM 
        ventas
    WHERE 
        ws_ship_mode_sk is not null
    GROUP BY ws_ship_mode_sk
    ORDER BY recuento DESC
    LIMIT 5;

                                            18	50008839
                                            8	50002844
                                            14	50000803
                                            7	50000034
                                            13	49999103


    SELECT 
        APPROX_TOP_K(ws_ship_mode_sk, 5) 
    FROM ventas;
                                                [
                                                    [
                                                        18,
                                                        50008839
                                                    ],
                                                    [
                                                        8,
                                                        50002844
                                                    ],
                                                    [
                                                        14,
                                                        50000803
                                                    ],
                                                    [
                                                        7,
                                                        50000034
                                                    ],
                                                    [
                                                        13,
                                                        49999103
                                                    ]
                                                ]

---

| id | empleado_id | comisionado |

Los 5 empleados_ids que más han comisionado

SELECT 
    empleado_id, 
    MAX(comisionado) as maximo_comisionado
WHERE 
    comisionado is not null
GROUP BY 
    empleado_id
SORT maximo_comisionado DESC
LIMIT 5;