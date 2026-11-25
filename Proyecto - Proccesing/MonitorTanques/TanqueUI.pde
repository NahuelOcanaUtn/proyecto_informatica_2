/**
 * ============================================================================
 * ARCHIVO DE LIBRERIA PROPIA: TanqueUI.pde
 * Contiene la Clase CTanque (POO), Lista Enlazada y Método Numérico (TP9)
 * ============================================================================
 *
 * ============================================================================
 * MEMORIA DESCRIPTIVA - TRABAJO PRACTICO N.º 9 (CALCULO NUMERICO)
 * Proyecto Final: Sistema SCADA de Monitoreo y Control de 3 Tanques (Tema 7)
 * ============================================================================
 *
 * 1. PROBLEMA A RESOLVER:
 *    En su versión base, el sistema opera de forma puramente reactiva:
 *    abre la válvula de seguridad recién cuando el líquido alcanza o supera el
 *    umbral crítico (N >= N_umbral). En una planta real, esta reacción tardía
 *    impide anticipar maniobras preventivas o detectar llenados anómalos con
 *    caudal creciente. Se necesita estimar en tiempo real cuántos segundos
 *    faltan para que cada tanque alcance su umbral crítico a partir de las
 *    muestras periódicas recibidas desde el Arduino o el simulador.
 *
 * 2. METODO SELECCIONADO Y FUNDAMENTO TEORICO:
 *    Se combinan derivación numérica discreta (diferencias hacia atrás para
 *    estimar velocidad v0 = dN/dt y aceleración a0 = dv/dt) con el método
 *    abierto de búsqueda de raíces de NEWTON-RAPHSON.
 *
 *    Modelando localmente la evolución del nivel como una función cuadrática:
 *        N(t) = N0 + v0 * t + 0.5 * a0 * t^2
 *
 *    El tiempo crítico t* se obtiene hallando la raíz positiva de:
 *        f(t)  = N(t) - N_umbral = (N0 - N_umbral) + v0 * t + 0.5 * a0 * t^2 = 0
 *        f'(t) = v0 + a0 * t
 *
 *    Fórmula iterativa de Newton-Raphson:
 *        t_{n+1} = t_n - f(t_n) / f'(t_n)
 *
 *    Criterio de parada: |t_{n+1} - t_n| < tolerancia (0.0001 s) o maxIter = 30.
 *    Resguardos numéricos implementados:
 *      - Verificación de discriminante real (v0^2 - 2*a0*(N0 - N_umbral) >= 0)
 *        cuando hay desaceleración (a0 < 0), evitando ciclos sin raíz real.
 *      - Protección contra división por cero si |f'(t)| < 1e-6.
 *      - Estimación inicial t0 basada en proyección lineal positiva para
 *        garantizar convergencia hacia la raíz física t > 0.
 *
 *    Comparativa de métodos analizados:
 *      - Newton-Raphson (Elegido): convergencia cuadrática (2 a 5 iteraciones),
 *        costo de CPU despreciable en tiempo real; requiere f'(t) y resguardos.
 *      - Bisección: convergencia garantizada pero lineal y lenta; exige
 *        acotar previamente un intervalo [ta, tb] con cambio de signo.
 *      - Euler explícito: usado como apoyo para simular la trayectoria N_{k+1}
 *        = N_k + v_k * dt en el modo ensayo, pero por sí solo requeriría
 *        integrar paso a paso hasta cruzar el umbral para hallar t*.
 *
 * 3. CODIGO DEFINITIVO IMPLEMENTADO EN EL PROYECTO FINAL:
 *    Integrado dentro de la clase CTanque en los métodos:
 *      - actualizarCinematica(float nuevoNivel)
 *      - calcularTiempoUmbralNR()
 *      - actualizarDinamica()
 *    Y visualizado en tiempo real en dibujarPanelPredictivoNR() y en el log
 *    de eventos (ALERTA_PREDICTIVA_NR) dentro de MonitorTanques.pde.
 *
 * 4. CONCLUSIONES:
 *    La incorporación de Newton-Raphson transforma el monitor
 *    reactivo a un sistema predictivo capaz de alertar con anticipación al
 *    operador. En las pruebas preliminares (C++ en ZinjaI) y en la ejecución
 *    en tiempo real en Processing, el algoritmo converge en menos de 5
 *    iteraciones con error menor a 10^-4 s, sin afectar la fluidez de la
 *    interfaz gráfica ni la comunicación serie con el Arduino.
 * ============================================================================
 */

// [ESTRUCTURAS Y LISTAS ENLAZADAS]
class NodoAlarma {
  int idTanque;
  float nivelRegistrado;
  String horaEvento;
  NodoAlarma siguiente;

  NodoAlarma(int id, float nivel, String hora) {
    this.idTanque = id;
    this.nivelRegistrado = nivel;
    this.horaEvento = hora;
    this.siguiente = null;
  }
}

class ListaAlarmas {
  private NodoAlarma cabeza;

  ListaAlarmas() {
    cabeza = null;
  }

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
// [POO - DECLARACION DE CLASE, ENCAPSULAMIENTO Y CALCULO NUMERICO (TP9)]
// ============================================================================
class CTanque {
  // Atributos de estado físico y control
  private int m_id;
  private float m_nivelActual;
  private float m_umbralCritico;
  private boolean m_valvulaAbierta;

  // Atributos de cinemática discreta y Newton-Raphson (TP9)
  private float m_nivelAnterior;
  private float m_velocidad;            // v0 (%/s)
  private float m_aceleracion;          // a0 (%/s^2)
  private long  m_tiempoUltimaMuestraMs;
  private boolean m_tieneMuestraPrevia;
  private float m_tiempoCriticoEstimado; // segundos (>0), 0 si en alarma, -1 si no aplica
  private int   m_iteracionesNR;         // iteraciones usadas para converger

  // Atributos geométricos para el dibujo
  private float m_posX, m_posY, m_ancho, m_alto;

  public CTanque(int id, float umbralInicial, float x, float y, float ancho, float alto) {
    this.m_id = id;
    this.m_nivelActual = 0.0;
    this.m_valvulaAbierta = false;
    this.m_posX = x;
    this.m_posY = y;
    this.m_ancho = ancho;
    this.m_alto = alto;

    reiniciarCinematica();
    setUmbralCritico(umbralInicial);
  }

  // Reinicia derivadas y predicción (útil al iniciar/detener simulaciones)
  public void reiniciarCinematica() {
    m_nivelAnterior = m_nivelActual;
    m_velocidad = 0.0;
    m_aceleracion = 0.0;
    m_tiempoUltimaMuestraMs = millis();
    m_tieneMuestraPrevia = false;
    m_tiempoCriticoEstimado = -1.0;
    m_iteracionesNR = 0;
  }

  // [POO - SETTERS CON VALIDACION Y ACTUALIZACION NUMERICA]
  public void setNivel(float nuevoNivel) {
    float nivelValidado = constrain(nuevoNivel, 0.0, 100.0);
    actualizarCinematica(nivelValidado);
    m_nivelActual = nivelValidado;
    evaluarSeguridad();
    m_tiempoCriticoEstimado = calcularTiempoUmbralNR();
  }

  public void setUmbralCritico(float nuevoUmbral) {
    if (nuevoUmbral >= 10.0 && nuevoUmbral <= 100.0) {
      m_umbralCritico = nuevoUmbral;
    } else {
      m_umbralCritico = 80.0;
    }
    evaluarSeguridad();
    m_tiempoCriticoEstimado = calcularTiempoUmbralNR();
  }

  // Estima v = dN/dt y a = dv/dt a partir de la variación temporal entre muestras
  private void actualizarCinematica(float nuevoNivel) {
    long ahoraMs = millis();
    float dt = (ahoraMs - m_tiempoUltimaMuestraMs) / 1000.0;

    if (m_tieneMuestraPrevia && dt >= 0.05 && dt <= 6.0) {
      float vInst = (nuevoNivel - m_nivelAnterior) / dt;

      // Filtrado exponencial suave para amortiguar saltos bruscos de teclado o ruido
      float alphaV = 0.6;
      float vNueva = (abs(m_velocidad) < 0.001) ? vInst : (alphaV * vInst + (1.0 - alphaV) * m_velocidad);

      float aInst = constrain((vNueva - m_velocidad) / dt, -5.0, 5.0);
      float alphaA = 0.35;
      m_aceleracion = alphaA * aInst + (1.0 - alphaA) * m_aceleracion;
      m_velocidad = vNueva;
    } else if (dt > 6.0) {
      // Si pasó mucho tiempo sin cambios, reinicia la tendencia
      m_velocidad = 0.0;
      m_aceleracion = 0.0;
    }

    m_nivelAnterior = nuevoNivel;
    m_tiempoUltimaMuestraMs = ahoraMs;
    m_tieneMuestraPrevia = true;
  }

  // Se llama en cada frame: si el tanque lleva >3.5 s quieto, limpia la velocidad
  public void actualizarDinamica() {
    if (m_tieneMuestraPrevia && (millis() - m_tiempoUltimaMuestraMs) > 3500) {
      if (abs(m_velocidad) > 0.0 || abs(m_aceleracion) > 0.0) {
        m_velocidad = 0.0;
        m_aceleracion = 0.0;
        m_tiempoCriticoEstimado = m_valvulaAbierta ? 0.0 : -1.0;
        m_iteracionesNR = 0;
      }
    }
  }

  // ==========================================================================
  // [TP9 - METODO NUMERICO: NEWTON-RAPHSON]
  // Resuelve f(t) = (N0 - N_umbral) + v0*t + 0.5*a0*t^2 = 0
  // ==========================================================================
  private float funcionNivel(float t) {
    return (m_nivelActual - m_umbralCritico)
           + m_velocidad * t
           + 0.5 * m_aceleracion * t * t;
  }

  private float derivadaNivel(float t) {
    return m_velocidad + m_aceleracion * t;
  }

  public float calcularTiempoUmbralNR() {
    m_iteracionesNR = 0;

    // 1. Si ya alcanzó o superó el umbral, tiempo restante = 0
    if (m_nivelActual >= m_umbralCritico) {
      return 0.0;
    }

    // 2. Si no está subiendo ni acelerando positivamente, no llegará al umbral
    if (m_velocidad <= 0.05 && m_aceleracion <= 0.02) {
      return -1.0;
    }

    // 3. Si desacelera (a < 0), verifica que exista raíz real (discriminante >= 0)
    float c = m_nivelActual - m_umbralCritico; // valor negativo
    float discriminante = m_velocidad * m_velocidad - 2.0 * m_aceleracion * c;
    if (discriminante < 0.0) {
      return -1.0; // El caudal se frena antes de llegar al umbral
    }

    // 4. Estimación inicial t0 (proyección lineal positiva)
    float t;
    if (m_velocidad > 0.05) {
      t = constrain((m_umbralCritico - m_nivelActual) / m_velocidad, 0.1, 300.0);
    } else {
      t = sqrt(2.0 * (m_umbralCritico - m_nivelActual) / m_aceleracion);
    }

    // 5. Bucle iterativo de Newton-Raphson
    final float TOLERANCIA = 0.0001;
    final int MAX_ITER = 30;

    for (int i = 0; i < MAX_ITER; i++) {
      m_iteracionesNR++;
      float ft  = funcionNivel(t);
      float dft = derivadaNivel(t);

      // Protección contra derivada nula
      if (abs(dft) < 1e-6) {
        return -1.0;
      }

      float tNuevo = t - (ft / dft);

      if (abs(tNuevo - t) < TOLERANCIA) {
        return (tNuevo > 0.0 && tNuevo <= 3600.0) ? tNuevo : -1.0;
      }
      t = tNuevo;
    }
    return -1.0; // No convergió dentro de MAX_ITER
  }

  private void evaluarSeguridad() {
    m_valvulaAbierta = (m_nivelActual >= m_umbralCritico);
  }

  // [POO - GETTERS]
  public int getId()                { return m_id; }
  public float getNivel()           { return m_nivelActual; }
  public float getUmbral()          { return m_umbralCritico; }
  public boolean isValvulaAbierta() { return m_valvulaAbierta; }
  public float getVelocidad()       { return m_velocidad; }
  public float getAceleracion()     { return m_aceleracion; }
  public float getTiempoCritico()   { return m_tiempoCriticoEstimado; }
  public int getIteracionesNR()     { return m_iteracionesNR; }

  // [INTERFAZ GRAFICA DEL TANQUE Y PANEL PREDICTIVO TP9]
  public void dibujar() {
    // 1. Estructura exterior del tanque
    stroke(40);
    strokeWeight(2.5);
    fill(235, 240, 245);
    rect(m_posX, m_posY, m_ancho, m_alto, 8);

    // 2. Semáforo de criticidad
    if (m_valvulaAbierta) {
      fill(230, 55, 55);   // ROJO: umbral superado
    } else if (m_nivelActual >= (m_umbralCritico - 15.0) || (m_tiempoCriticoEstimado > 0 && m_tiempoCriticoEstimado <= 10.0)) {
      fill(245, 190, 40);  // AMARILLO: cercanía física o alerta predictiva NR
    } else {
      fill(45, 185, 95);   // VERDE: normal
    }

    // 3. Líquido proporcional
    float alturaLiquido = map(m_nivelActual, 0, 100, 0, m_alto - 6);
    noStroke();
    rect(m_posX + 3, (m_posY + m_alto - 3) - alturaLiquido, m_ancho - 6, alturaLiquido, 0, 0, 6, 6);

    // 4. Línea de Umbral Crítico
    float yUmbral = (m_posY + m_alto) - map(m_umbralCritico, 0, 100, 0, m_alto);
    stroke(180, 0, 0);
    strokeWeight(2);
    line(m_posX - 5, yUmbral, m_posX + m_ancho + 5, yUmbral);
    fill(180, 0, 0);
    textSize(11);
    textAlign(LEFT, BOTTOM);
    text("Umbral: " + nf(m_umbralCritico, 0, 0) + "%", m_posX + 5, yUmbral - 3);

    // 5. Textos de telemetría
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(16);
    text("TANQUE " + m_id, m_posX + m_ancho / 2, m_posY - 20);

    textSize(18);
    text(nf(m_nivelActual, 0, 1) + " %", m_posX + m_ancho / 2, m_posY + m_alto / 2);

    // 6. Indicador de Válvula
    float yValvula = m_posY + m_alto + 28;
    stroke(30);
    strokeWeight(1.5);
    fill(m_valvulaAbierta ? color(255, 60, 60) : color(180));
    ellipse(m_posX + m_ancho / 2, yValvula, 24, 24);

    fill(20);
    textSize(11);
    text(m_valvulaAbierta ? "VÁLVULA: ABIERTA" : "VÁLVULA: CERRADA", m_posX + m_ancho / 2, yValvula + 22);

    // 7. Botones de umbral y tarjeta de Cálculo Numérico (TP9)
    dibujarBotonesUmbral();
    dibujarPanelPredictivoNR();
  }

  private void dibujarBotonesUmbral() {
    float yBtn = m_posY + m_alto + 66;
    stroke(60);
    strokeWeight(1);

    fill(220);
    rect(m_posX + 10, yBtn, 45, 24, 4);
    rect(m_posX + m_ancho - 55, yBtn, 45, 24, 4);

    fill(0);
    textSize(12);
    textAlign(CENTER, CENTER);
    text("-5%", m_posX + 32, yBtn + 12);
    text("+5%", m_posX + m_ancho - 32, yBtn + 12);
  }

  // Tarjeta visual del resultado de Newton-Raphson debajo de cada tanque (Ejercicio 4)
  private void dibujarPanelPredictivoNR() {
    float xBox = m_posX - 25;
    float yBox = m_posY + m_alto + 98;
    float wBox = m_ancho + 50;
    float hBox = 66;

    // Fondo y borde según estado predictivo
    strokeWeight(1.2);
    if (m_valvulaAbierta) {
      fill(255, 235, 235);
      stroke(200, 60, 60);
    } else if (m_tiempoCriticoEstimado > 0 && m_tiempoCriticoEstimado <= 15.0) {
      fill(255, 247, 224);
      stroke(215, 145, 0);
    } else {
      fill(242, 246, 250);
      stroke(180);
    }
    rect(xBox, yBox, wBox, hBox, 6);

    float cx = xBox + wBox / 2;
    textAlign(CENTER, CENTER);

    fill(60);
    textSize(10);
    text("PREDICCIÓN NEWTON-RAPHSON", cx, yBox + 13);

    fill(40);
    textSize(11);
    String signoV = (m_velocidad >= 0) ? "+" : "";
    String signoA = (m_aceleracion >= 0) ? "+" : "";
    text("v: " + signoV + nf(m_velocidad, 0, 2) + " %/s  |  a: " + signoA + nf(m_aceleracion, 0, 2), cx, yBox + 31);

    textSize(12);
    if (m_valvulaAbierta) {
      fill(200, 30, 30);
      text("UMBRAL ALCANZADO (0.0 s)", cx, yBox + 50);
    } else if (m_tiempoCriticoEstimado > 0) {
      fill(m_tiempoCriticoEstimado <= 15.0 ? color(195, 95, 0) : color(30, 100, 175));
      text("T. CRÍTICO: " + nf(m_tiempoCriticoEstimado, 0, 1) + " s (" + m_iteracionesNR + " it.)", cx, yBox + 50);
    } else if (m_velocidad < -0.05) {
      fill(35, 140, 75);
      text("VACIANDO (SIN RIESGO)", cx, yBox + 50);
    } else {
      fill(110);
      text("NIVEL ESTABLE (-- s)", cx, yBox + 50);
    }
  }

  public int verificarClicUmbral(int mx, int my) {
    float yBtn = m_posY + m_alto + 66;
    if (mx >= m_posX + 10 && mx <= m_posX + 55 && my >= yBtn && my <= yBtn + 24) {
      return -5;
    }
    if (mx >= m_posX + m_ancho - 55 && mx <= m_posX + m_ancho - 10 && my >= yBtn && my <= yBtn + 24) {
      return 5;
    }
    return 0;
  }
}
