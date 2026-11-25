
int trig = 10;
int eco = 9;

int ledR = 11;
int ledA = 12;
int ledV = 13;

int MOT = 8;

long duracion;
float distancia;
float nivel;

const int alturaTanque = 337;

bool valvulaAbierta = false;

void setup() {
  pinMode(trig, OUTPUT);
  pinMode(eco, INPUT);

  pinMode(ledR, OUTPUT);
  pinMode(ledA, OUTPUT);
  pinMode(ledV, OUTPUT);

  pinMode(MOT, OUTPUT);

  digitalWrite(MOT, LOW);
}

void loop() {

  // Medicion del sensor ultrasonico
  digitalWrite(trig, LOW);
  delayMicroseconds(2);

  digitalWrite(trig, HIGH);
  delayMicroseconds(10);

  digitalWrite(trig, LOW);

  duracion = pulseIn(eco, HIGH, 30000);//Esta instrucción mide cuánto tiempo permanece en HIGH el pin eco y 30000us el tiempo maximo de espera cuando recibe la señal pasa a low eco.



  if (duracion == 0) {
    digitalWrite(MOT, LOW);
    valvulaAbierta = false;

    digitalWrite(ledR, HIGH);
    digitalWrite(ledA, LOW);
    digitalWrite(ledV, LOW);

    delay(500);
    return;
  }

  distancia = duracion / 58.2;

  // Calculo del porcentaje de agua
  nivel = (alturaTanque - distancia) * 100.0 / alturaTanque;

  nivel = constrain(nivel, 0, 100);  //limitamos el valor de la variable
  

  // Control de la valvula con histeresis
  if (nivel >= 90) {
    valvulaAbierta = true;
  }

  if (nivel <= 25) {
    valvulaAbierta = false;
  }

  digitalWrite(MOT, valvulaAbierta ? HIGH : LOW);

  // Indicadores LED
  if (nivel >= 90) {
    digitalWrite(ledV, HIGH);
    digitalWrite(ledA, LOW);
    digitalWrite(ledR, LOW);
  }
  else if (nivel > 25) {
    digitalWrite(ledV, LOW);
    digitalWrite(ledA, HIGH);
    digitalWrite(ledR, LOW);
  }
  else {
    digitalWrite(ledV, LOW);
    digitalWrite(ledA, LOW);
    digitalWrite(ledR, HIGH);
  }

  delay(500);
}
