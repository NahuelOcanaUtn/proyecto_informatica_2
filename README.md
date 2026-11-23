# Trabajo Final Integrador: Sistema de Monitoreo y Control de 4 Tanques (Tema 7)

**Universidad:** Universidad Tecnológica Nacional - Facultad Regional Mendoza (UTN FRM)  
**Cátedra:** Informática II  
**Ciclo Lectivo:** 2026  

**Integrantes:**  
* **Ocaña, Nahuel Agustín** *(Desarrollo de Interfaz Gráfica en Processing)*  
* **Quispe, Cristian** *(Desarrollo Arduino UNO, Sensores y Actuadores)*  

---

## 1. Descripción del Proyecto (Tema 7)
Desarrollo de un prototipo para medir en tiempo real el nivel de líquido de **4 tanques independientes**. Sobre cada tanque se evalúa un umbral crítico configurable; en caso de que alguno de los niveles alcance o supere dicho límite, el sistema acciona automáticamente su **válvula de seguridad** e indicadores luminosos/sonoros de alerta.  

Desde la interfaz gráfica en **Processing** se visualiza tanto la simulación en tiempo real (con código de colores industrial Verde / Amarillo / Rojo para el operador) como el registro histórico almacenado en disco.

---

## 2. Estructura Actual del Repositorio

* **`/Proyecto - Proccesing/MonitorTanques`** *(Implementado)*:
  * `MonitorTanques.pde`: Programa principal en Processing, máquina de estados visual, recepción/envío por puerto serie y manejo de archivos.
  * `TanqueUI.pde`: Librería propia con la declaración e implementación de la clase `CTanque` y las estructuras de nodos para la lista enlazada de alarmas (`NodoAlarma` y `ListaAlarmas`).
  * `historico_tanques.csv`: Archivo de persistencia generado en modo *append* con el historial de mediciones y aperturas de válvulas.
* **`/Proyecto - Arduino`** *(En desarrollo - Cristian Quispe)*:
  * Controlador de hardware en C++ para Arduino UNO + Shield, lectura de los 4 sensores analógicos de nivel y accionamiento de válvulas.

---

## 3. Unidades Temáticas de la Materia Aplicadas en Processing

1. **Programación Orientada a Objetos (POO) y Librería Propia:**
   * Implementación de la clase `CTanque` en `TanqueUI.pde` aplicando encapsulamiento (`private` para atributos sensibles de nivel/umbral y `public` para constructores, *getters* y *setters* con validación semántica).
2. **Máquina de Estados**
   * Alternancia estructurada mediante `switch(estadoActual)` entre `ESTADO_TIEMPO_REAL` (monitoreo y mando de umbrales) y `ESTADO_HISTORICO` (lectura y visualización de registros).
3. **Manejo de Archivos en Modo Append:**
   * Almacenamiento continuo en `historico_tanques.csv` utilizando `FileWriter(..., true)` en modo *append* (agregando nuevos registros al final sin sobrescribir ni borrar los datos anteriores) y lectura mediante `loadStrings()`.
4. **Contenedores en Memoria y Listas Enlazadas:**
   * Arreglo estático de objetos `CTanque[4]` para gestionar el llenado de tanques.
   * Contenedor dinámico `ArrayList<String>` para la paginación del archivo histórico.
   * Lista enlazada simple autorreferenciada (`NodoAlarma`) en memoria RAM para registrar los eventos críticos de apertura de válvulas en tiempo real.
5. **Protocolo de Comunicación Serie Bidireccional (9600 bps):**
   * **Sentido Arduino $\to$ PC (Telemetría enmarcada):** `"M,nivel1,nivel2,nivel3,nivel4,F\n"` (Ejemplo: `M,45.0,82.5,30.0,60.0,F`).
   * **Sentido PC $\to$ Arduino (Configuración de umbrales):** `"U,idTanque,nuevoUmbral\n"` (Ejemplo: `U,2,75.0`).

---

## 4. Controles de Prueba y Simulación en PC
Cuando se ejecuta `MonitorTanques.pde` sin la placa Arduino conectada por USB, el sistema inicia automáticamente en **Modo Simulación**:
* **Subir nivel (+8%):** Teclas `1`, `2`, `3`, `4` (para Tanques 1 al 4).
* **Bajar nivel (-8%):** Teclas `Q`, `W`, `E`, `R` (para Tanques 1 al 4).
* **Modificar Umbral Crítico ($\pm 5\%$):** Botones `-5%` y `+5%` debajo de cada tanque con el mouse.
* **Consultar Histórico CSV:** Botón superior derecho `VER HISTÓRICO (CSV)`.
