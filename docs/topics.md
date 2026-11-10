# Topics de Kafka de Biblioteca

`kafka/topics.sh` declara los topics. Los brokers tienen desactivada la creación automática. El script usa `--if-not-exists` para que un segundo arranque conserve el topic y su configuración.

| Topic | Quién publica | Clave | Política y retención |
| --- | --- | --- | --- |
| `biblioteca.prestamos` | Préstamos y el simulador | `usuarioSub` | `delete`, 7 días. Permite volver a leer la actividad semanal. |
| `biblioteca.lecturas` | Simulador | `libroId` | `delete`, 24 horas. El panel y las alertas consultan ventanas recientes. |
| `biblioteca.prestamos.dlt` | Se incorpora en el siguiente laboratorio | Clave del mensaje original | `delete`, 7 días para revisar rechazos. |
| `biblioteca.lecturas.dlt` | Se incorpora en el siguiente laboratorio | Clave del mensaje original | `delete`, 7 días para revisar rechazos. |
| `biblioteca.catalogo` | Libros | `libroId` | `compact`. Cada evento contiene el libro completo y Kafka conserva su último estado por clave. |

## Orden, capacidad y tolerancia a fallos

- **Orden.** El préstamo y su devolución usan el mismo `usuarioSub`, por lo que caen en una misma partición. Historial puede consultar el préstamo antes de aplicar la devolución. En Lecturas, `libroId` concentra la actividad de un libro en una partición. Así se mantiene el orden por libro, aunque un libro muy activo puede concentrar carga.
- **Tres particiones.** Un grupo que lee un topic puede tener tres consumidores activos con una partición cada uno. Las asignaciones son independientes entre grupos.
- **Tres réplicas, `min.insync.replicas=2` y `acks=all`.** Con tres copias, la pérdida de un broker aún permite escribir si las otras dos réplicas siguen sincronizadas. El productor espera la confirmación de las réplicas sincronizadas y el broker exige que haya al menos dos.
- **Catálogo compactado.** Se usa el identificador del libro como clave. Hasta que Kafka compacte el segmento, pueden convivir el evento original y la actualización. Al reconstruir, Eventos conserva el estado más reciente.
