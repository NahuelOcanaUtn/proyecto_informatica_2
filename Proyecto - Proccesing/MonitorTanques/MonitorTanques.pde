/**
 * ============================================================================
 * PROGRAMA PRINCIPAL: MonitorTanques.pde
 * Monitoreo de 3 Tanques - Datos/Eventos Históricos + Predicción TP9 (Newton-Raphson)
 * ============================================================================
 */

import processing.serial.*;
import java.io.FileWriter;
import java.io.BufferedWriter;
import java.io.PrintWriter;
import java.io.File;

// [MAQUINA DE ESTADOS)]
final int ESTADO_TIEMPO_REAL = 0;
final int ESTADO_HISTORICO   = 1;
int estadoActual = ESTADO_TIEMPO_REAL;
boolean mostrandoEventos = false;

// [CONTENEDORES EN MEMORIA - ARREGLO DE OBJETOS, ARRAYLISTS Y LISTA ENLAZADA]
final int CANT_TANQUES = 3;
CTanque[] tanques = new CTanque[CANT_TANQUES];
boolean[] estadoAnteriorValvula = new boolean[CANT_TANQUES];
boolean[] alertaPredictivaActiva = new boolean[CANT_TANQUES]; // Evita repetir ALERTA_PREDICTIVA_NR

ArrayList<String> historialDatos   = new ArrayList<String>();
ArrayList<String> historialEventos = new ArrayList<String>();
ListaAlarmas listaEnlazadaAlarmas  = new ListaAlarmas();

// Variables de Comunicación Serie
Serial miPuerto;
boolean arduinoConectado = false;

// Variables para el manejo de los 2 Archivos CSV
final String ARCHIVO_DATOS   = "historico_datos.csv";
final String ARCHIVO_EVENTOS = "historico_eventos.csv";
long ultimoGuardado = 0;
int intervaloGuardadoMs = 5000;

// Variables de Simulación Continua (Ensayo de validación TP9 con tecla 'S')
boolean simulacionContinuaNR = false;
long ultimoPasoSimMs = 0;
float velocidadSimTanque1 = 2.0;    // %/s inicial
float aceleracionSimTanque1 = 0.20; // %/s^2 (aceleración de caudal)

void setup() {
  size(920, 620);
  pixelDensity(displayDensity()); 
  smooth(8);                      
  
  PFont fuenteNitida = createFont("Segoe UI", 16, true);
  textFont(fuenteNitida);
  
  surface.setTitle("Proyecto Final Informática II - Tema 7: Sistema de 3 Tanques (TP9 Newton-Raphson)");

  // [POO - INSTANCIACION E INICIALIZACION DE OBJETOS]
  float margenX = 150;
  float separacion = 240;
  float[] umbralesIniciales = {80.0, 75.0, 85.0};
  
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i] = new CTanque(i + 1, umbralesIniciales[i], margenX + i * separacion, 105, 140, 225);
    estadoAnteriorValvula[i] = false;
    alertaPredictivaActiva[i] = false;
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
    println("[INFO] Sin Arduino detectado. MODO SIMULACION ACTIVO ([1..3]/[Q..E] manual, [S] ensayo NR).");
  }

  // Cargar datos y eventos previos desde disco
  leerArchivoEnLista(ARCHIVO_DATOS, historialDatos);
  leerArchivoEnLista(ARCHIVO_EVENTOS, historialEventos);

  String modo = arduinoConectado ? "ARDUINO CONECTADO" : "MODO SIMULACION";
  registrarEventoHistorico("INICIO_SISTEMA", "SCADA iniciado (" + modo + ")");
}

void draw() {
  background(248, 250, 252);
  dibujarEncabezadoYBotones();

  // Simulación continua de llenado para validar Newton-Raphson (tecla 'S')
  if (!arduinoConectado && simulacionContinuaNR) {
    ejecutarPasoSimulacionNR();
  }

  // Actualización de cinemática y detección de eventos
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i].actualizarDinamica();
  }
  verificarEventosYPredicciones();

  // Guardado periódico de DATOS HISTÓRICOS cada 5 segundos
  if (millis() - ultimoGuardado >= intervaloGuardadoMs) {
    ultimoGuardado = millis();
    guardarDatosHistoricosAppend();
  }

  // [MAQUINA DE ESTADO]
  switch (estadoActual) {
    case ESTADO_TIEMPO_REAL:
      ejecutarVistaTiempoReal();
      break;

    case ESTADO_HISTORICO:
      ejecutarVistaHistorico();
      break;
  }
}

// Simula un llenado acelerado por integración de Euler (cada 250 ms) en el Tanque 1
void ejecutarPasoSimulacionNR() {
  long ahora = millis();
  if (ahora - ultimoPasoSimMs >= 250) {
    float dt = (ahora - ultimoPasoSimMs) / 1000.0;
    ultimoPasoSimMs = ahora;

    velocidadSimTanque1 += aceleracionSimTanque1 * dt;
    float nuevoNivel = tanques[0].getNivel() + velocidadSimTanque1 * dt;
    tanques[0].setNivel(nuevoNivel);

    if (tanques[0].getNivel() >= 95.0) {
      simulacionContinuaNR = false; // Detiene automáticamente tras superar umbral
    }
  }
}

// ----------------------------------------------------------------------------
// ESTADO 0: VISTA DE MONITOREO EN TIEMPO REAL
// ----------------------------------------------------------------------------
void ejecutarVistaTiempoReal() {
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i].dibujar();
  }
  dibujarPanelListaEnlazada();
}

// ----------------------------------------------------------------------------
// ESTADO 1: VISTA DE HISTÓRICOS (PESTAÑAS: DATOS VS. EVENTOS)
// ----------------------------------------------------------------------------
void ejecutarVistaHistorico() {
  stroke(150);
  strokeWeight(1);
  fill(!mostrandoEventos ? color(30, 50, 80) : color(220));
  rect(50, 80, 210, 32, 6);
  fill(!mostrandoEventos ? 255 : 40);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("DATOS HISTÓRICOS", 155, 96);

  fill(mostrandoEventos ? color(180, 45, 45) : color(220));
  rect(270, 80, 210, 32, 6);
  fill(mostrandoEventos ? 255 : 40);
  text("EVENTOS HISTÓRICOS", 375, 96);

  fill(70);
  textAlign(RIGHT, CENTER);
  textSize(13);
  text("Archivo: " + (mostrandoEventos ? ARCHIVO_EVENTOS : ARCHIVO_DATOS), width - 50, 96);

  fill(255);
  stroke(180);
  rect(50, 122, width - 100, 445, 6);

  fill(40);
  textAlign(LEFT, TOP);
  textSize(13);
  if (!mostrandoEventos) {
    text("FECHA Y HORA        | TANQUE 1 | TANQUE 2 | TANQUE 3 | ESTADO VÁLVULAS", 70, 136);
  } else {
    text("FECHA Y HORA        | TIPO DE EVENTO       | DETALLE", 70, 136);
  }
  line(65, 158, width - 65, 158);

  ArrayList<String> listaActiva = mostrandoEventos ? historialEventos : historialDatos;
  int fila = 0;
  for (int i = listaActiva.size() - 1; i >= 0 && fila < 16; i--) {
    String linea = listaActiva.get(i);
    if (linea.contains("ALERTA_VALVULA") || linea.contains("APERTURA_VALVULA")) {
      fill(200, 30, 30);
    } else if (linea.contains("ALERTA_PREDICTIVA_NR")) {
      fill(195, 100, 0);
    } else if (linea.contains("CIERRE_VALVULA")) {
      fill(30, 140, 70);
    } else if (linea.contains("CAMBIO_UMBRAL")) {
      fill(30, 90, 180);
    } else {
      fill(50);
    }
    text(linea, 70, 170 + fila * 23);
    fila++;
  }
}

// ============================================================================
// [DETECCION DE EVENTOS POR FLANCOS Y ALERTAS PREDICTIVAS TP9]
// ============================================================================
void verificarEventosYPredicciones() {
  for (int i = 0; i < CANT_TANQUES; i++) {
    boolean abiertaAhora = tanques[i].isValvulaAbierta();

    // 1. Flancos de apertura y cierre de válvula
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

    // 2. Alerta predictiva anticipada por Newton-Raphson (cuando t* <= 10 s)
    float tCrit = tanques[i].getTiempoCritico();
    if (!abiertaAhora && tCrit > 0.0 && tCrit <= 10.0) {
      if (!alertaPredictivaActiva[i]) {
        alertaPredictivaActiva[i] = true;
        String detalleNR = "Tanque " + tanques[i].getId() + " alcanzara umbral en " + nf(tCrit, 0, 1) +
                           " s (v=" + nf(tanques[i].getVelocidad(), 0, 2) + " %/s, " + tanques[i].getIteracionesNR() + " it.)";
        registrarEventoHistorico("ALERTA_PREDICTIVA_NR", detalleNR);
      }
    } else if (abiertaAhora || tCrit < 0.0 || tCrit > 15.0) {
      alertaPredictivaActiva[i] = false;
    }
  }
}

// ============================================================================
// [MANEJO DE ARCHIVOS - MODO APPEND Y LECTURA PARA AMBOS CSV]
// ============================================================================
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

void registrarEventoHistorico(String tipoEvento, String detalle) {
  String lineaEvento = obtenerTimestamp() + " | " + tipoEvento + " | " + detalle;
  escribirLineaEnArchivoAppend(ARCHIVO_EVENTOS, lineaEvento);
  historialEventos.add(lineaEvento);
}

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
// INTERACCION CON MOUSE Y TECLADO
// ============================================================================
void mousePressed() {
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

  if (estadoActual == ESTADO_TIEMPO_REAL) {
    for (int i = 0; i < CANT_TANQUES; i++) {
      int cambio = tanques[i].verificarClicUmbral(mouseX, mouseY);
      if (cambio != 0) {
        float umbralAnterior = tanques[i].getUmbral();
        float nuevoUmbral = umbralAnterior + cambio;
        tanques[i].setUmbralCritico(nuevoUmbral);

        if (tanques[i].getUmbral() != umbralAnterior) {
          enviarUmbralAlArduino(tanques[i].getId(), tanques[i].getUmbral());
          registrarEventoHistorico("CAMBIO_UMBRAL", "Tanque " + tanques[i].getId() +
                                   " | " + nf(umbralAnterior, 0, 0) + "% -> " + nf(tanques[i].getUmbral(), 0, 0) + "%");
        }
      }
    }
  }

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

void keyPressed() {
  if (key == '1') tanques[0].setNivel(tanques[0].getNivel() + 8);
  if (key == 'q' || key == 'Q') tanques[0].setNivel(tanques[0].getNivel() - 8);
  
  if (key == '2') tanques[1].setNivel(tanques[1].getNivel() + 8);
  if (key == 'w' || key == 'W') tanques[1].setNivel(tanques[1].getNivel() - 8);
  
  if (key == '3') tanques[2].setNivel(tanques[2].getNivel() + 8);
  if (key == 'e' || key == 'E') tanques[2].setNivel(tanques[2].getNivel() - 8);

  // Tecla 'S': inicia o detiene el ensayo automático de llenado para validar Newton-Raphson
  if ((key == 's' || key == 'S') && !arduinoConectado) {
    simulacionContinuaNR = !simulacionContinuaNR;
    if (simulacionContinuaNR) {
      if (tanques[0].getNivel() >= tanques[0].getUmbral() - 10.0) {
        tanques[0].setNivel(15.0);
      }
      tanques[0].reiniciarCinematica();
      velocidadSimTanque1 = 2.0;
      ultimoPasoSimMs = millis();
    }
  }
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
  text("SISTEMA DE 3 TANQUES", 25, 32);

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
  rect(45, 515, width - 90, 82, 6);

  fill(30);
  textAlign(LEFT, TOP);
  textSize(12);
  text("ÚLTIMAS ALARMAS:", 60, 524);

  NodoAlarma aux = listaEnlazadaAlarmas.getCabeza();
  int mostrados = 0;
  String textoAlarmas = "";
  while (aux != null && mostrados < 2) {
    textoAlarmas += "[" + aux.horaEvento + " -> T" + aux.idTanque + " en " + nf(aux.nivelRegistrado, 0, 1) + "%]   ";
    aux = aux.siguiente;
    mostrados++;
  }
  
  fill(mostrados > 0 ? color(190, 20, 20) : color(90));
  text(mostrados > 0 ? textoAlarmas : "Sin aperturas de válvulas registradas en esta sesión.", 60, 548);

  fill(simulacionContinuaNR ? color(195, 95, 0) : color(95));
  textAlign(RIGHT, TOP);
  String estadoSim = simulacionContinuaNR ? " | [S] DETENER ENSAYO NR (ACTIVO)" : " | [S] ENSAYO LLENADO NR";
  text("Manual: [1..3] Subir / [Q..E] Bajar" + estadoSim, width - 60, 573);
}

// Devuelve la fecha y hora actual en formato dd/MM/yyyy 
String obtenerTimestamp() {
  String fecha = nf(day(), 2) + "/" + nf(month(), 2) + "/" + nf(year(), 4);
  String hora  = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  return fecha + " " + hora;
}
