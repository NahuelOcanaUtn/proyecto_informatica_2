#include <iostream>
#include <string>

using namespace std;

// ============================================================================
// 1. DECLARACIÓN DE LA CLASE (Interfaz)
// ============================================================================
class CTanque 
{
private:
    // Atributos privados: la información interna protegida
    int   m_iId;              // Identificador del tanque (1, 2, 3, etc.)
    float m_fNivelActual;     // Nivel de líquido medido (0.0 a 100.0 %)
    float m_fUmbralCritico;   // Nivel a partir del cual se abre la válvula
    bool  m_bValvulaAbierta;  // Estado del actuador (true: abierta, false: cerrada)

public:
    // Constructores (Sobrecarga de constructores)
    CTanque();
    CTanque(int iId, float fUmbral);

    // Métodos de acción y lógica del tanque
    void  AsignarNivel(float fNivel);
    void  VerificarSeguridad(void);
    void  AbrirValvula(void);
    void  CerrarValvula(void);

    // Métodos para consultar información (Getters)
    float DevuelveNivel(void);
    bool  EstaValvulaAbierta(void);
    void  MostrarEstado(void);
};

// ============================================================================
// 2. IMPLEMENTACIÓN DE MÉTODOS FUERA DE LA CLASE (Operador ::)
// ============================================================================

/**
 * Constructor por defecto: inicializa atributos con valores seguros
 */
CTanque::CTanque() 
{
    m_iId = 0;
    m_fNivelActual = 0.0f;
    m_fUmbralCritico = 80.0f; // Umbral de fábrica: 80%
    m_bValvulaAbierta = false;
}

/**
 * Constructor parametrizado: inicializa el tanque con su ID y umbral deseado
 */
CTanque::CTanque(int iId, float fUmbral) 
{
    m_iId = iId;
    m_fNivelActual = 0.0f;
    m_bValvulaAbierta = false;

    // Validación semántica del umbral
    if (fUmbral > 0.0f && fUmbral <= 100.0f) {
        m_fUmbralCritico = fUmbral;
    } else {
        m_fUmbralCritico = 80.0f;
    }
}

/**
 * Actualiza el nivel actual del tanque y evalúa la válvula de inmediato
 */
void CTanque::AsignarNivel(float fNivel) 
{
    if (fNivel < 0.0f) {
        m_fNivelActual = 0.0f;
    } else if (fNivel > 100.0f) {
        m_fNivelActual = 100.0f;
    } else {
        m_fNivelActual = fNivel;
    }

    // Al recibir un nuevo nivel, se evalúa la condición de seguridad
    VerificarSeguridad();
}

/**
 * Controla la válvula de seguridad en función del umbral
 */
void CTanque::VerificarSeguridad(void) 
{
    if (m_fNivelActual >= m_fUmbralCritico) {
        AbrirValvula();
    } else {
        CerrarValvula();
    }
}

void CTanque::AbrirValvula(void) 
{
    m_bValvulaAbierta = true;
}

void CTanque::CerrarValvula(void) 
{
    m_bValvulaAbierta = false;
}

float CTanque::DevuelveNivel(void) 
{
    return m_fNivelActual;
}

bool CTanque::EstaValvulaAbierta(void) 
{
    return m_bValvulaAbierta;
}

/**
 * Muestra el estado del tanque por consola
 */
void CTanque::MostrarEstado(void) 
{
    cout << "Tanque #" << m_iId 
         << " | Nivel: " << m_fNivelActual << "%"
         << " | Umbral: " << m_fUmbralCritico << "%"
         << " | Valvula: ";

    if (m_bValvulaAbierta) {
        cout << "[ABIERTA - ALERTA ALTA]" << endl;
    } else {
        cout << "[CERRADA - NORMAL]" << endl;
    }
}

// ============================================================================
// 3. PROGRAMA PRINCIPAL (Declaración, inicialización y uso de objetos)
// ============================================================================
int main(void) 
{
    cout << "==========================================================" << endl;
    cout << "   SISTEMA DE SEGURIDAD DE TANQUES (INFO II - UTN FRM)    " << endl;
    cout << "==========================================================" << endl;

    // A. Declarar e inicializar objetos usando el Constructor Parametrizado
    // Representamos los tanques requeridos para el Trabajo Final (Tema 7)
    CTanque tanque1(1, 80.0f); // Tanque 1 con umbral en 80%
    CTanque tanque2(2, 75.0f); // Tanque 2 con umbral en 75%
    CTanque tanque3(3, 90.0f); // Tanque 3 con umbral en 90%
    CTanque tanque4(4, 70.0f); // Tanque 4 con umbral en 70%

    // B. Estado inicial de los objetos
    cout << "\n--- ESTADO INICIAL DE LOS TANQUES ---" << endl;
    tanque1.MostrarEstado();
    tanque2.MostrarEstado();
    tanque3.MostrarEstado();
    tanque4.MostrarEstado();

    // C. Utilización de métodos: simulamos lecturas de sensores de nivel
    cout << "\n--- ASIGNANDO NIVELES DE LIQUIDO ---" << endl;
    
    // El Tanque 1 recibe 55% (nivel seguro, por debajo del umbral de 80%)
    tanque1.AsignarNivel(55.0f);

    // El Tanque 2 recibe 88% (SUPERA el umbral de 75% -> dispara la válvula)
    tanque2.AsignarNivel(88.5f);

    // El Tanque 3 recibe 40% (nivel seguro)
    tanque3.AsignarNivel(40.0f);

    // El Tanque 4 recibe 95% (SUPERA el umbral de 70% -> dispara la válvula)
    tanque4.AsignarNivel(95.0f);

    // D. Comprobación del accionamiento mediante MostrarEstado()
    cout << "\n--- ESTADO TRAS LA MEDICION (EVALUACION DE VALVULAS) ---" << endl;
    tanque1.MostrarEstado();
    tanque2.MostrarEstado();
    tanque3.MostrarEstado();
    tanque4.MostrarEstado();

    // E. Uso individual de métodos Getters
    cout << "\n--- VERIFICACION PUNTUAL ---" << endl;
    if (tanque2.EstaValvulaAbierta()) {
        cout << "[AVISO CRITICO] Tanque 2 en emergencia con " 
             << tanque2.DevuelveNivel() << "% de llenado." << endl;
    }

    cout << "\nPrograma finalizado con exito." << endl;
    return 0;
}