/**
 * ============================================================================
 * PROGRAMA PRINCIPAL: MonitorTanques.pde
 * Monitoreo de 3 Tanques
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

// [CONTENEDORES EN MEMORIA - ARREGLO DE OBJETOS Y ARRAYLIST]
final int CANT_TANQUES = 3;
CTanque[] tanques = new CTanque[CANT_TANQUES]; // Arreglo de 3 objetos CTanque
ArrayList<String> historialArchivo = new ArrayList<String>(); // ArrayList dinámico (.add)
ListaAlarmas listaEnlazadaAlarmas = new ListaAlarmas();       // Lista enlazada propia

// Variables de Comunicación Serie
Serial miPuerto;
boolean arduinoConectado = false;

// Variables para el manejo de Archivos
final String NOMBRE_ARCHIVO = "historico_tanques.csv";
long ultimoGuardado = 0;        // Control de tiempo en ms (tipo long en Processing)
int intervaloGuardadoMs = 3000; // Guarda en disco cada 3 segundos

void setup() {
  size(920, 560);
  pixelDensity(displayDensity()); 
  smooth(8);                      
  
  // Carga una fuente vectorial nítida del sistema para que el texto no se pixele
  PFont fuenteNitida = createFont("Segoe UI", 16, true);
  textFont(fuenteNitida);
  
  surface.setTitle("Proyecto Final Informática II - Tema 7: Sistema de 3 Tanques");

  // [POO - INSTANCIACION E INICIALIZACION DE OBJETOS]
  // Centrado en 920 px: 3 tanques de 140 px, separación 240 px -> márgenes izq/der de 150 px
  float margenX = 150;
  float separacion = 240;
  float[] umbralesIniciales = {80.0, 75.0, 85.0};
  
  for (int i = 0; i < CANT_TANQUES; i++) {
    tanques[i] = new CTanque(i + 1, umbralesIniciales[i], margenX + i * separacion, 110, 140, 240);
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

  // Cargar datos previos del archivo al iniciar
  leerArchivoHistorico();
}

void draw() {
  background(248, 250, 252);
  dibujarEncabezadoYBotones();

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

  // Guardado periódico en archivo modo append
  if (millis() - ultimoGuardado >= intervaloGuardadoMs) {
    ultimoGuardado = millis();
    guardarRegistroEnArchivoAppend();
  }

  // Panel inferior con las últimas alarmas de la Lista Enlazada en RAM
  dibujarPanelListaEnlazada();
}

// ----------------------------------------------------------------------------
// ESTADO 1: VISTA DE HISTÓRICO LEÍDO DESDE EL ARCHIVO CSV
// ----------------------------------------------------------------------------
void ejecutarVistaHistorico() {
  fill(30);
  textAlign(LEFT, TOP);
  textSize(18);
  text("REGISTRO HISTÓRICO DE MEDICIONES (Archivo: " + NOMBRE_ARCHIVO + ")", 50, 85);

  fill(255);
  stroke(180);
  rect(50, 115, width - 100, 380, 6);

  fill(40);
  textSize(13);
  text("FECHA Y HORA          | TANQUE 1 | TANQUE 2 | TANQUE 3 | ESTADO VÁLVULAS", 70, 130);
  line(65, 150, width - 65, 150);

  int fila = 0;
  for (int i = historialArchivo.size() - 1; i >= 0 && fila < 14; i--) {
    String linea = historialArchivo.get(i);
    fill(linea.contains("ALERTA") ? color(200, 30, 30) : color(50));
    text(linea, 70, 162 + fila * 22);
    fila++;
  }
}

// ============================================================================
// [MANEJO DE ARCHIVOS - MODO APPEND Y LECTURA]
// ============================================================================
void guardarRegistroEnArchivoAppend() {
  String timestamp = obtenerTimestamp();
  boolean hayValvulaAbierta = false;

  for (int i = 0; i < CANT_TANQUES; i++) {
    if (tanques[i].isValvulaAbierta()) {
      hayValvulaAbierta = true;
      listaEnlazadaAlarmas.insertarAlInicio(tanques[i].getId(), tanques[i].getNivel(), timestamp);
    }
  }

  String estadoGeneral = hayValvulaAbierta ? "ALERTA_VALVULA_ABIERTA" : "NORMAL";
  String lineaCSV = timestamp;
  for (int i = 0; i < CANT_TANQUES; i++) {
    lineaCSV += " | T" + (i + 1) + ": " + nf(tanques[i].getNivel(), 0, 1) + "%";
  }
  lineaCSV += " | " + estadoGeneral;

  // 1. Guardar en disco en modo APPEND (true = agregar al final, false = pisar archivo)
  try {
    File archivo = new File(sketchPath(NOMBRE_ARCHIVO));
    FileWriter fw = new FileWriter(archivo, true);
    BufferedWriter bw = new BufferedWriter(fw);
    PrintWriter salida = new PrintWriter(bw);
    salida.println(lineaCSV);
    salida.close();
  } catch (Exception e) {
    println("[ERROR ARCHIVO] No se pudo escribir en " + NOMBRE_ARCHIVO);
  }

  // 2. Agregar al contenedor ArrayList en memoria usando .add()
  historialArchivo.add(lineaCSV);
}

void leerArchivoHistorico() {
  File archivo = new File(sketchPath(NOMBRE_ARCHIVO));
  if (archivo.exists()) {
    String[] lineas = loadStrings(archivo);
    if (lineas != null) {
      historialArchivo.clear();
      for (int i = 0; i < lineas.length; i++) {
        historialArchivo.add(lineas[i]);
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
    
    // Verifica carácter de inicio 'M' (Medición), 3 niveles y fin 'F' -> M,n1,n2,n3,F
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
  // 1. Botón de cambio de Estado (Tiempo Real <-> Histórico)
  if (mouseX >= width - 210 && mouseX <= width - 30 && mouseY >= 15 && mouseY <= 50) {
    if (estadoActual == ESTADO_TIEMPO_REAL) {
      leerArchivoHistorico();
      estadoActual = ESTADO_HISTORICO;
    } else {
      estadoActual = ESTADO_TIEMPO_REAL;
    }
  }

  // 2. Si estamos en Tiempo Real, verificar clics en botones de umbral de cada tanque
  if (estadoActual == ESTADO_TIEMPO_REAL) {
    for (int i = 0; i < CANT_TANQUES; i++) {
      int cambio = tanques[i].verificarClicUmbral(mouseX, mouseY);
      if (cambio != 0) {
        float nuevoUmbral = tanques[i].getUmbral() + cambio;
        tanques[i].setUmbralCritico(nuevoUmbral);
        enviarUmbralAlArduino(tanques[i].getId(), tanques[i].getUmbral());
      }
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
  text("SISTEMA DE MONITOREO DE 3 TANQUES Y VÁLVULAS", 25, 32);

  stroke(255);
  strokeWeight(1.5);
  fill(estadoActual == ESTADO_TIEMPO_REAL ? color(50, 130, 200) : color(45, 160, 90));
  rect(width - 210, 15, 180, 35, 6);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(13);
  text(estadoActual == ESTADO_TIEMPO_REAL ? "VER HISTÓRICO (CSV)" : "VOLVER A TIEMPO REAL", width - 120, 32);
}

void dibujarPanelListaEnlazada() {
  fill(235);
  stroke(190);
  rect(45, 475, width - 90, 65, 6);

  fill(30);
  textAlign(LEFT, TOP);
  textSize(12);
  text("ÚLTIMAS ALARMAS:", 60, 483);

  NodoAlarma aux = listaEnlazadaAlarmas.getCabeza();
  int mostrados = 0;
  String textoAlarmas = "";
  while (aux != null && mostrados < 3) {
    textoAlarmas += "[" + aux.horaEvento + " -> Tanque " + aux.idTanque + " en " + nf(aux.nivelRegistrado, 0, 1) + "%]   ";
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
