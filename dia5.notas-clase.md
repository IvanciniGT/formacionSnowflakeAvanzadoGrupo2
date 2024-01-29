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


-- Dame el ID de los productos (ws_item_sk)  que se han vendido con más cobro (ws_net_paid máximo)
SELECT 
    ws_item_sk
    , MAX(ws_net_paid) as importe_maximo
FROM 
    ventas
WHERE 
    ws_net_paid is not null
GROUP BY 
    ws_item_sk
ORDER BY importe_maximo DESC
LIMIT 5;
            WS_ITEM_SK	IMPORTE_MAXIMO
            194707	29970.00
            390197	29867.00
            288328	29810.00
            209947	29705.00
            305408	29703.00
---
SELECT 
    MAX_BY(ws_item_sk,ws_net_paid, 5) -- ESTE ES REAL... no aproximado
FROM ventas;
            [
            194707,
            390197,
            288328,
            209947,
            30973
            ]

305408 y 30973 tienen el mismo maximo... y toma uno de ellos.            

SELECT ws_item_sk, ws_net_sold FROM ventas WHERE ws_item_sk IN (305408, 30973);
