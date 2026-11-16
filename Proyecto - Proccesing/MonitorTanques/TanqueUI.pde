/**
 * ============================================================================
 * ARCHIVO DE LIBRERIA PROPIA: TanqueUI.pde
 * Contiene la Clase CTanque (POO) y la estructura de Nodos para Lista Enlazada
 * ============================================================================
 */

// [ESTRUCTURAS Y LISTAS ENLAZADAS]
// Estructura autorreferenciada (Nodo) para almacenar eventos de alarma en memoria RAM.
class NodoAlarma {
  int idTanque;
  float nivelRegistrado;
  String horaEvento;
  NodoAlarma siguiente; // Puntero (referencia) al siguiente nodo de la lista

  NodoAlarma(int id, float nivel, String hora) {
    this.idTanque = id;
    this.nivelRegistrado = nivel;
    this.horaEvento = hora;
    this.siguiente = null;
  }
}

// Clase administradora de la Lista Enlazada Simple de Alarmas
class ListaAlarmas {
  private NodoAlarma cabeza; // Puntero al inicio de la lista

  ListaAlarmas() {
    cabeza = null;
  }
  // Aquí se agrega AL PRINCIPIO (LIFO) para mostrar primero la alarma más reciente.
  // Si quisiéramos agregar AL FINAL (FIFO), recorreríamos con un while(aux.siguiente != null).
  public void insertarAlInicio(int id, float nivel, String hora) {
    NodoAlarma nuevo = new NodoAlarma(id, nivel, hora);
    nuevo.siguiente = cabeza;
    cabeza = nuevo;
  }

  public NodoAlarma getCabeza() {
    return cabeza;
  }
}

// ============================================================================
// [POO - DECLARACION DE CLASE Y ENCAPSULAMIENTO]
// ============================================================================
class CTanque {
  // Atributos PRIVADOS (Encapsulamiento): ocultos al programa principal para
  // evitar que se asignen niveles inválidos (ej. negativos o mayores a 100%).
  private int m_id;
  private float m_nivelActual;
  private float m_umbralCritico;
  private boolean m_valvulaAbierta;
  
  // Atributos geométricos para el dibujo
  private float m_posX, m_posY, m_ancho, m_alto;

  // [POO - CONSTRUCTOR PARAMETRIZADO]
  // Se ejecuta automáticamente una única vez al instanciar cada tanque.
  public CTanque(int id, float umbralInicial, float x, float y, float ancho, float alto) {
    this.m_id = id;
    this.m_nivelActual = 0.0;
    this.m_valvulaAbierta = false;
    this.m_posX = x;
    this.m_posY = y;
    this.m_ancho = ancho;
    this.m_alto = alto;
    setUmbralCritico(umbralInicial); 
  }

  // [POO - METODOS SETTERS Y VALIDACION SEMANTICA]
  public void setNivel(float nuevoNivel) {
    if (nuevoNivel < 0.0) {
      m_nivelActual = 0.0;
    } else if (nuevoNivel > 100.0) {
      m_nivelActual = 100.0;
    } else {
      m_nivelActual = nuevoNivel;
    }
    evaluarSeguridad();
  }

  public void setUmbralCritico(float nuevoUmbral) {
    if (nuevoUmbral >= 10.0 && nuevoUmbral <= 100.0) {
      m_umbralCritico = nuevoUmbral;
    } else {
      m_umbralCritico = 80.0;
    }
    evaluarSeguridad();
  }

  // Lógica interna de seguridad del tanque
  private void evaluarSeguridad() {
    if (m_nivelActual >= m_umbralCritico) {
      m_valvulaAbierta = true;  // Abre válvula de seguridad al superar umbral
    } else {
      m_valvulaAbierta = false; // Cierra válvula en estado normal
    }
  }

  // [POO - METODOS GETTERS (CONSULTORES)]
  public int getId() { return m_id; }
  public float getNivel() { return m_nivelActual; }
  public float getUmbral() { return m_umbralCritico; }
  public boolean isValvulaAbierta() { return m_valvulaAbierta; }

  // [INTERFAZ GRAFICA Y SEMAFORO PARA EL OPERADOR]
  // Dibuja el tanque con código de colores industrial (Verde / Amarillo / Rojo)
  public void dibujar() {
    // 1. Sombra y estructura exterior del tanque
    stroke(40);
    strokeWeight(2.5);
    fill(235, 240, 245);
    rect(m_posX, m_posY, m_ancho, m_alto, 8);

    // 2. Selección de color según criticidad para decisión rápida del operador
    if (m_valvulaAbierta) {
      fill(230, 55, 55);   // ZONA ROJA: Peligro / Umbral superado
    } else if (m_nivelActual >= (m_umbralCritico - 15.0)) {
      fill(245, 190, 40);  // ZONA AMARILLA: Precaución (cerca del umbral)
    } else {
      fill(45, 185, 95);   // ZONA VERDE: Operación normal
    }

    // 3. Dibujo del líquido proporcional al porcentaje (0 a 100%)
    float alturaLiquido = map(m_nivelActual, 0, 100, 0, m_alto - 6);
    noStroke();
    rect(m_posX + 3, (m_posY + m_alto - 3) - alturaLiquido, m_ancho - 6, alturaLiquido, 0, 0, 6, 6);

    // 4. Línea indicadora del Umbral Crítico
    float yUmbral = (m_posY + m_alto) - map(m_umbralCritico, 0, 100, 0, m_alto);
    stroke(180, 0, 0);
    strokeWeight(2);
    line(m_posX - 5, yUmbral, m_posX + m_ancho + 5, yUmbral);
    fill(180, 0, 0);
    textSize(11);
    textAlign(LEFT, BOTTOM);
    text("Umbral: " + nf(m_umbralCritico, 0, 0) + "%", m_posX + 5, yUmbral - 3);

    // 5. Textos de telemetría del tanque
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(16);
    text("TANQUE " + m_id, m_posX + m_ancho/2, m_posY - 22);
    
    textSize(18);
    text(nf(m_nivelActual, 0, 1) + " %", m_posX + m_ancho/2, m_posY + m_alto/2);

    // 6. Indicador de Válvula de Seguridad (Actuador)
    float yValvula = m_posY + m_alto + 35;
    stroke(30);
    strokeWeight(1.5);
    if (m_valvulaAbierta) {
      fill(255, 60, 60);
    } else {
      fill(180);
    }
    ellipse(m_posX + m_ancho/2, yValvula, 28, 28);
    
    fill(20);
    textSize(12);
    text(m_valvulaAbierta ? "VALVULA: ABIERTA" : "VALVULA: CERRADA", m_posX + m_ancho/2, yValvula + 26);

    // 7. Botones '+' y '-' para cambiar el umbral desde la PC (Comunicación PC -> Arduino)
    dibujarBotonesUmbral();
  }

  private void dibujarBotonesUmbral() {
    float yBtn = m_posY + m_alto + 80;
    stroke(60);
    strokeWeight(1);
    
    // Botón [- Umbral]
    fill(220);
    rect(m_posX + 10, yBtn, 45, 24, 4);
    // Botón [+ Umbral]
    rect(m_posX + m_ancho - 55, yBtn, 45, 24, 4);
    
    fill(0);
    textSize(12);
    text("-5%", m_posX + 32, yBtn + 12);
    text("+5%", m_posX + m_ancho - 32, yBtn + 12);
  }

  // Detecta clics sobre los botones de umbral de este tanque
  public int verificarClicUmbral(int mx, int my) {
    float yBtn = m_posY + m_alto + 80;
    if (mx >= m_posX + 10 && mx <= m_posX + 55 && my >= yBtn && my <= yBtn + 24) {
      return -5; // Bajar umbral 5%
    }
    if (mx >= m_posX + m_ancho - 55 && mx <= m_posX + m_ancho - 10 && my >= yBtn && my <= yBtn + 24) {
      return 5;  // Subir umbral 5%
    }
    return 0;
  }
}
