/**
 * ============================================================================
 * PROGRAMA PRINCIPAL: MonitorTanques.pde
 * Monitoreo de 3 Tanques - Separación de Datos Históricos y Eventos Históricos
 * ============================================================================
 */

import processing.serial.*;
import java.io.FileWriter;
import java.io.BufferedWriter;
import java.io.PrintWriter;
import java.io.File;

// [MAQUINA DE ESTADOS (FSM)]
final int ESTADO_TIEMPO_REAL = 0;
final int ESTADO_HISTORICO   = 1;
int estadoActual = ESTADO_TIEMPO_REAL;
boolean mostrandoEventos = false; // Sub-vista dentro de ESTADO_HISTORICO (false = Datos, true = Eventos)

// [CONTENEDORES EN MEMORIA - ARREGLO DE OBJETOS, ARRAYLISTS Y LISTA ENLAZADA]
final int CANT_TANQUES = 3;
CTanque[] tanques = new CTanque[CANT_TANQUES];
boolean[] estadoAnteriorValvula = new boolean[CANT_TANQUES]; // Para detectar transiciones (flancos)

ArrayList<String> historialDatos   = new ArrayList<String>(); // Contenido de historico_datos.csv
ArrayList<String> historialEventos = new ArrayList<String>(); // Contenido de historico_eventos.csv
ListaAlarmas listaEnlazadaAlarmas  = new ListaAlarmas();      // Lista enlazada propia en RAM

// Variables de Comunicación Serie
Serial miPuerto;
boolean arduinoConectado = false;

// Variables para el manejo de los 2 Archivos CSV
final String ARCHIVO_DATOS   = "historico_datos.csv";
final String ARCHIVO_EVENTOS = "historico_eventos.csv";
long ultimoGuardado = 0;        // Control de tiempo en ms
int intervaloGuardadoMs = 3000; // Guarda datos históricos cada 3 segundos

void setup() {
  size(920, 560);
  pixelDensity(displayDensity()); 
  smooth(8);                      
  
  PFont fuenteNitida = createFont("Segoe UI", 16, true);
  textFont(fuenteNitida);
  
  surface.setTitle("Proyecto Final Informática II - Tema 7: Sistema de 3 Tanques");

  // [POO - INSTANCIACION E INICIALIZACION DE OBJETOS]
  float margenX = 150;
  float separacion = 240;
  float[] umbralesIniciales = {80.0, 75.0, 85.0};
  
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i] = new CTanque(i + 1, umbralesIniciales[i], margenX + i * separacion, 110, 140, 240);
    estadoAnteriorValvula[i] = false;
  }

  // Inicialización del Puerto Serie
  printArray(Serial.list());
  if (Serial.list().length > 0) {
    try {
      miPuerto = new Serial(this, Serial.list()[0], 9600);
      miPuerto.bufferUntil('\n');
      arduinoConectado = true;
      println("[OK] Arduino conectado en: " + Serial.list()[0]);
    } catch (Exception e) {
      arduinoConectado = false;
      println("[!] Puerto ocupado. Ejecutando en MODO SIMULACION.");
    }
  } else {
    println("[INFO] Sin Arduino detectado. MODO SIMULACION ACTIVO (Teclas 1..3 suben nivel, Q..E bajan nivel).");
  }

  // Cargar datos y eventos previos desde disco al iniciar
  leerArchivoEnLista(ARCHIVO_DATOS, historialDatos);
  leerArchivoEnLista(ARCHIVO_EVENTOS, historialEventos);

  // Registrar evento de arranque del sistema
  String modo = arduinoConectado ? "ARDUINO CONECTADO" : "MODO SIMULACION";
  registrarEventoHistorico("INICIO_SISTEMA", "SCADA iniciado (" + modo + ")");
}

void draw() {
  background(248, 250, 252);
  dibujarEncabezadoYBotones();

  // Detección continua de eventos de válvulas (funciona en cualquier vista)
  verificarEventosValvulas();

  // Guardado periódico de DATOS HISTÓRICOS cada 3 segundos
  if (millis() - ultimoGuardado >= intervaloGuardadoMs) {
    ultimoGuardado = millis();
    guardarDatosHistoricosAppend();
  }

  // ==========================================================================
  // [MAQUINA DE ESTADO]
  // ==========================================================================
  switch (estadoActual) {
    case ESTADO_TIEMPO_REAL:
      ejecutarVistaTiempoReal();
      break;

    case ESTADO_HISTORICO:
      ejecutarVistaHistorico();
      break;
  }
}

// ----------------------------------------------------------------------------
// ESTADO 0: VISTA DE MONITOREO EN TIEMPO REAL
// ----------------------------------------------------------------------------
void ejecutarVistaTiempoReal() {
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i].dibujar();
  }

  // Panel inferior con las últimas alarmas de la Lista Enlazada en RAM
  dibujarPanelListaEnlazada();
}

// ----------------------------------------------------------------------------
// ESTADO 1: VISTA DE HISTÓRICOS (PESTAÑAS: DATOS VS. EVENTOS)
// ----------------------------------------------------------------------------
void ejecutarVistaHistorico() {
  // Pestaña 1: Datos Históricos
  stroke(150);
  strokeWeight(1);
  fill(!mostrandoEventos ? color(30, 50, 80) : color(220));
  rect(50, 80, 210, 32, 6);
  fill(!mostrandoEventos ? 255 : 40);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("DATOS HISTÓRICOS", 155, 96);

  // Pestaña 2: Eventos Históricos
  fill(mostrandoEventos ? color(180, 45, 45) : color(220));
  rect(270, 80, 210, 32, 6);
  fill(mostrandoEventos ? 255 : 40);
  text("EVENTOS HISTÓRICOS", 375, 96);

  // Nombre del archivo activo a la derecha
  fill(70);
  textAlign(RIGHT, CENTER);
  textSize(13);
  text("Archivo: " + (mostrandoEventos ? ARCHIVO_EVENTOS : ARCHIVO_DATOS), width - 50, 96);

  // Panel de tabla
  fill(255);
  stroke(180);
  rect(50, 122, width - 100, 390, 6);

  fill(40);
  textAlign(LEFT, TOP);
  textSize(13);
  if (!mostrandoEventos) {
    text("FECHA Y HORA        | TANQUE 1 | TANQUE 2 | TANQUE 3 | ESTADO VÁLVULAS", 70, 136);
  } else {
    text("FECHA Y HORA        | TIPO DE EVENTO    | DETALLE", 70, 136);
  }
  line(65, 158, width - 65, 158);

  // Listado de las últimas 14 filas del archivo seleccionado
  ArrayList<String> listaActiva = mostrandoEventos ? historialEventos : historialDatos;
  int fila = 0;
  for (int i = listaActiva.size() - 1; i >= 0 && fila < 14; i--) {
    String linea = listaActiva.get(i);
    if (linea.contains("ALERTA") || linea.contains("APERTURA_VALVULA")) {
      fill(200, 30, 30);
    } else if (linea.contains("CIERRE_VALVULA")) {
      fill(30, 140, 70);
    } else if (linea.contains("CAMBIO_UMBRAL")) {
      fill(30, 90, 180);
    } else {
      fill(50);
    }
    text(linea, 70, 170 + fila * 22);
    fila++;
  }
}

// ============================================================================
// [DETECCION DE EVENTOS POR CAMBIO DE ESTADO (FLANCOS)]
// ============================================================================
void verificarEventosValvulas() {
  for (int i = 0; i < CANT_TANQUES; i++) {
    boolean abiertaAhora = tanques[i].isValvulaAbierta();

    if (abiertaAhora != estadoAnteriorValvula[i]) {
      estadoAnteriorValvula[i] = abiertaAhora;
      String detalle = "Tanque " + tanques[i].getId() + " | Nivel: " + nf(tanques[i].getNivel(), 0, 1) +
                       "% (Umbral: " + nf(tanques[i].getUmbral(), 0, 0) + "%)";

      if (abiertaAhora) {
        registrarEventoHistorico("APERTURA_VALVULA", detalle);
        listaEnlazadaAlarmas.insertarAlInicio(tanques[i].getId(), tanques[i].getNivel(), obtenerTimestamp());
      } else {
        registrarEventoHistorico("CIERRE_VALVULA", detalle);
      }
    }
  }
}

// ============================================================================
// [MANEJO DE ARCHIVOS - MODO APPEND Y LECTURA PARA AMBOS CSV]
// ============================================================================

// 1. Archivo de DATOS HISTÓRICOS (muestreo periódico)
void guardarDatosHistoricosAppend() {
  String timestamp = obtenerTimestamp();
  boolean hayValvulaAbierta = false;

  for (int i = 0; i < CANT_TANQUES; i++) {
    if (tanques[i].isValvulaAbierta()) {
      hayValvulaAbierta = true;
    }
  }

  String estadoGeneral = hayValvulaAbierta ? "ALERTA_VALVULA_ABIERTA" : "NORMAL";
  String lineaCSV = timestamp;
  for (int i = 0; i < CANT_TANQUES; i++) {
    lineaCSV += " | T" + (i + 1) + ": " + nf(tanques[i].getNivel(), 0, 1) + "%";
  }
  lineaCSV += " | " + estadoGeneral;

  escribirLineaEnArchivoAppend(ARCHIVO_DATOS, lineaCSV);
  historialDatos.add(lineaCSV);
}

// 2. Archivo de EVENTOS HISTÓRICOS (cambios de estado y acciones del operador)
void registrarEventoHistorico(String tipoEvento, String detalle) {
  String lineaEvento = obtenerTimestamp() + " | " + tipoEvento + " | " + detalle;
  escribirLineaEnArchivoAppend(ARCHIVO_EVENTOS, lineaEvento);
  historialEventos.add(lineaEvento);
}

// Función genérica reutilizable para escribir una línea al final (APPEND) de cualquier archivo
void escribirLineaEnArchivoAppend(String nombreArchivo, String linea) {
  try {
    File archivo = new File(sketchPath(nombreArchivo));
    FileWriter fw = new FileWriter(archivo, true);
    BufferedWriter bw = new BufferedWriter(fw);
    PrintWriter salida = new PrintWriter(bw);
    salida.println(linea);
    salida.close();
  } catch (Exception e) {
    println("[ERROR ARCHIVO] No se pudo escribir en " + nombreArchivo);
  }
}

// Función genérica reutilizable para cargar un archivo CSV a su ArrayList
void leerArchivoEnLista(String nombreArchivo, ArrayList<String> destino) {
  File archivo = new File(sketchPath(nombreArchivo));
  if (archivo.exists()) {
    String[] lineas = loadStrings(archivo);
    if (lineas != null) {
      destino.clear();
      for (int i = 0; i < lineas.length; i++) {
        destino.add(lineas[i]);
      }
    }
  }
}

// ============================================================================
// [COMUNICACION SERIE BIDIRECCIONAL ARDUINO <-> PC]
// ============================================================================
void serialEvent(Serial p) {
  String trama = p.readStringUntil('\n');
  if (trama != null) {
    trama = trim(trama);
    String[] partes = split(trama, ',');
    
    // Verifica carácter de inicio 'M', 3 niveles y fin 'F' -> M,n1,n2,n3,F
    if (partes.length == CANT_TANQUES + 2 && partes[0].equals("M") && partes[CANT_TANQUES + 1].equals("F")) {
      for (int i = 0; i < CANT_TANQUES; i++) {
        tanques[i].setNivel(float(partes[i + 1]));
      }
    }
  }
}

void enviarUmbralAlArduino(int idTanque, float nuevoUmbral) {
  String comando = "U," + idTanque + "," + nf(nuevoUmbral, 0, 1) + "\n";
  if (arduinoConectado) {
    miPuerto.write(comando);
  }
  println("[UART TX -> Arduino] " + trim(comando));
}

// ============================================================================
// INTERACCION CON MOUSE Y TECLADO (BOTONES Y MODO SIMULACION)
// ============================================================================
void mousePressed() {
  // 1. Botón principal de cambio de Estado (Tiempo Real <-> Histórico)
  if (mouseX >= width - 210 && mouseX <= width - 30 && mouseY >= 15 && mouseY <= 50) {
    if (estadoActual == ESTADO_TIEMPO_REAL) {
      leerArchivoEnLista(ARCHIVO_DATOS, historialDatos);
      leerArchivoEnLista(ARCHIVO_EVENTOS, historialEventos);
      estadoActual = ESTADO_HISTORICO;
    } else {
      estadoActual = ESTADO_TIEMPO_REAL;
    }
    return;
  }

  // 2. Si estamos en Tiempo Real, verificar clics en botones de umbral de cada tanque
  if (estadoActual == ESTADO_TIEMPO_REAL) {
    for (int i = 0; i < CANT_TANQUES; i++) {
      int cambio = tanques[i].verificarClicUmbral(mouseX, mouseY);
      if (cambio != 0) {
        float umbralAnterior = tanques[i].getUmbral();
        float nuevoUmbral = umbralAnterior + cambio;
        tanques[i].setUmbralCritico(nuevoUmbral);

        // Solo registra y envía si el umbral efectivamente cambió (dentro de 10..100%)
        if (tanques[i].getUmbral() != umbralAnterior) {
          enviarUmbralAlArduino(tanques[i].getId(), tanques[i].getUmbral());
          registrarEventoHistorico("CAMBIO_UMBRAL", "Tanque " + tanques[i].getId() +
                                   " | " + nf(umbralAnterior, 0, 0) + "% -> " + nf(tanques[i].getUmbral(), 0, 0) + "%");
        }
      }
    }
  }

  // 3. Si estamos en Histórico, verificar clics en las pestañas Datos / Eventos
  if (estadoActual == ESTADO_HISTORICO) {
    if (mouseX >= 50 && mouseX <= 260 && mouseY >= 80 && mouseY <= 112) {
      leerArchivoEnLista(ARCHIVO_DATOS, historialDatos);
      mostrandoEventos = false;
    } else if (mouseX >= 270 && mouseX <= 480 && mouseY >= 80 && mouseY <= 112) {
      leerArchivoEnLista(ARCHIVO_EVENTOS, historialEventos);
      mostrandoEventos = true;
    }
  }
}

// Teclas para simular subida/bajada de nivel sin tener el Arduino enchufado
void keyPressed() {
  if (key == '1') tanques[0].setNivel(tanques[0].getNivel() + 8);
  if (key == 'q' || key == 'Q') tanques[0].setNivel(tanques[0].getNivel() - 8);
  
  if (key == '2') tanques[1].setNivel(tanques[1].getNivel() + 8);
  if (key == 'w' || key == 'W') tanques[1].setNivel(tanques[1].getNivel() - 8);
  
  if (key == '3') tanques[2].setNivel(tanques[2].getNivel() + 8);
  if (key == 'e' || key == 'E') tanques[2].setNivel(tanques[2].getNivel() - 8);
}

// ============================================================================
// FUNCIONES AUXILIARES DE DIBUJO DE INTERFAZ
// ============================================================================
void dibujarEncabezadoYBotones() {
  noStroke();
  fill(30, 50, 80);
  rect(0, 0, width, 65);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(20);
  text("SISTEMA DE MONITOREO DE 3 TANQUES", 25, 32);

  stroke(255);
  strokeWeight(1.5);
  fill(estadoActual == ESTADO_TIEMPO_REAL ? color(50, 130, 200) : color(45, 160, 90));
  rect(width - 210, 15, 180, 35, 6);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(13);
  text(estadoActual == ESTADO_TIEMPO_REAL ? "VER HISTÓRICOS" : "VOLVER A TIEMPO REAL", width - 120, 32);
}

void dibujarPanelListaEnlazada() {
  fill(235);
  stroke(190);
  rect(45, 475, width - 90, 65, 6);

  fill(30);
  textAlign(LEFT, TOP);
  textSize(12);
  text("ÚLTIMAS ALARMAS (Lista Enlazada Dinámica):", 60, 483);

  NodoAlarma aux = listaEnlazadaAlarmas.getCabeza();
  int mostrados = 0;
  String textoAlarmas = "";
  while (aux != null && mostrados < 2) {
    textoAlarmas += "[" + aux.horaEvento + " -> T" + aux.idTanque + " en " + nf(aux.nivelRegistrado, 0, 1) + "%]   ";
    aux = aux.siguiente;
    mostrados++;
  }
  
  fill(mostrados > 0 ? color(190, 20, 20) : color(90));
  text(mostrados > 0 ? textoAlarmas : "Sin aperturas de válvulas registradas en esta sesión.", 60, 505);

  fill(100);
  textAlign(RIGHT, TOP);
  text("Teclas Simulación: [1..3] Subir Nivel | [Q..E] Bajar Nivel", width - 60, 483);
}

// Devuelve la fecha y hora actual en formato dd/MM/yyyy 
String obtenerTimestamp() {
  String fecha = nf(day(), 2) + "/" + nf(month(), 2) + "/" + nf(year(), 4);
  String hora  = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  return fecha + " " + hora;
}
