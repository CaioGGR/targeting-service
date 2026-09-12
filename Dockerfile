# ==========================================
# Estágio 1: Builder
# ==========================================
# Utilizamos uma imagem oficial do Python enxuta para construir as dependências
FROM python:3.9-slim AS builder

# Variáveis de ambiente para o Python não gerar arquivos .pyc e não usar buffer no stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Define o diretório de trabalho no estágio de build
WORKDIR /app

# Cria um ambiente virtual (venv) para isolar as dependências
RUN python -m venv /opt/venv

# Atualiza a variável PATH para usar os executáveis do ambiente virtual por padrão
ENV PATH="/opt/venv/bin:$PATH"

# Otimização de Cache: Copiamos apenas o requirements.txt primeiro.
# Como as dependências não mudam com a mesma frequência que o código da aplicação,
# isso permite que o Docker faça cache da camada de instalação se o arquivo não for alterado.
COPY requirements.txt .

# Instala as dependências dentro do ambiente virtual criado
RUN pip install --no-cache-dir -r requirements.txt

# ==========================================
# Estágio 2: Produção (Imagem Final Enxuta)
# ==========================================
# Usamos novamente a imagem slim para garantir que nossa imagem final seja o menor possível
FROM python:3.9-slim

# Mantemos as boas práticas do Python na imagem final
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Atualiza pacotes do sistema para mitigar vulnerabilidades de segurança da imagem base
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Segurança (Usuário Non-root):
# Criação de um grupo e usuário de sistema sem privilégios para executar a aplicação.
# Isso reduz o impacto de possíveis vulnerabilidades, pois a aplicação não rodará como root.
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# Define o diretório de trabalho
WORKDIR /app

# Copia o ambiente virtual com as dependências instaladas do estágio builder
# Assim evitamos a necessidade de ter ferramentas de build (compiladores, etc) na imagem final
COPY --from=builder /opt/venv /opt/venv

# Atualiza a variável PATH na imagem final para usar o ambiente virtual
ENV PATH="/opt/venv/bin:$PATH"

# Copia o restante do código-fonte da aplicação para o diretório de trabalho
COPY . /app

# Ajusta a propriedade (chown) dos arquivos para o usuário non-root criado
RUN chown -R appuser:appgroup /app

# Muda para o usuário non-root para os próximos comandos (incluindo o CMD de execução)
USER appuser

# Expõe a porta que a aplicação vai utilizar (8003 para o targeting-service)
EXPOSE 8003

# Comando para iniciar a aplicação usando o Gunicorn (servidor WSGI pronto para produção)
CMD ["gunicorn", "--bind", "0.0.0.0:8003", "app:app"]
