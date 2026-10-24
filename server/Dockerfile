# Generador de niveles de Flechas (API HTTP en Python).
FROM python:3.12-slim

WORKDIR /app

# Dependencias primero (mejor cache de capas).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Código del generador.
COPY generador ./generador

EXPOSE 8080

# Arranca la API con uvicorn.
CMD ["uvicorn", "generador.api:app", "--host", "0.0.0.0", "--port", "8080"]
