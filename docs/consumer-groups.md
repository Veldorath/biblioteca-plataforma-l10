# Consumer groups de Biblioteca

| Grupo | Lee | Escribe |
| --- | --- | --- |
| `biblioteca-panel` | Lecturas y préstamos | `kpi_minuto` |
| `biblioteca-alertas` | Lecturas | `ventanas_lectura` y `alertas` |
| `biblioteca-historial` | Préstamos | `prestamos_semana` y `prestamos_vistos` |
| `biblioteca-catalogo` | Catálogo | `catalogo_libros` |

## Grupos independientes

Panel y Alertas leen el mismo topic de lecturas con offsets separados. Panel e Historial también comparten el topic de préstamos. Para comprobarlo se repitió el dataset y se intentó rebobinar Historial. Kafka rechazó el cambio mientras el grupo estaba en estado `Stable` con un consumidor activo. Después de detener Eventos, se reiniciaron solo los offsets de Historial sobre Préstamos.

Salida de `kafka-consumer-groups.sh --describe` en el ensayo, recortada a las columnas relevantes:

| Grupo en préstamos | Partición | Offset guardado | Final | Lag |
| --- | ---: | ---: | ---: | ---: |
| Panel | 0 | 408 | 408 | 0 |
| Panel | 1 | 435 | 435 | 0 |
| Panel | 2 | 369 | 369 | 0 |
| Historial | 0 | 0 | 408 | 408 |
| Historial | 1 | 0 | 435 | 435 |
| Historial | 2 | 0 | 369 | 369 |

Se vaciaron las dos tablas derivadas de Historial y solo sus filas de `eventos_procesados`. Después de arrancar Eventos, Historial reconstruyó 380 préstamos, 18 devoluciones y 362 activos. El panel conservó 2.626 filas.

## Particiones por instancia

Salida de `kafka-consumer-groups.sh --describe --members` resumida por grupo:

| Grupo | Con tres instancias | Con cuatro instancias |
| --- | --- | --- |
| Alertas | 1, 1, 1 | 1, 1, 1, 0 |
| Panel | 2, 2, 2 | 2, 2, 1, 1 |
| Historial | 3 particiones en su topic | 1, 1, 1, 0 |

Alertas e Historial leen tres particiones en total. La cuarta instancia de cada grupo queda disponible para un nuevo reparto. Panel puede asignar trabajo a las cuatro porque lee seis particiones entre sus dos topics. Las instancias temporales se iniciaron con `docker compose run -d --no-deps`, que usa la red interna sin publicar el puerto del servicio.

## Regla de alertas y catálogo

Una ventana fija de cinco minutos genera alerta con al menos cinco lecturas terminadas y más del 20 % en error. Un error entre tres terminadas supera el porcentaje, pero es una muestra demasiado pequeña. En el ensayo se obtuvo una sola alerta: libro 10, 56 errores de 59 terminadas entre las 21:30 y las 21:35.

Catálogo reconstruyó 24 libros a partir de 25 mensajes: 24 publicaciones iniciales y una actualización del libro 3, que quedó con cuatro ejemplares. El topic aún conservaba ambas versiones de ese libro. El consumidor compara la hora del evento para conservar el estado más reciente.
