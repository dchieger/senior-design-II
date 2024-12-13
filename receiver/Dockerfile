FROM python:3.9-slim

WORKDIR /app

# Install watchdog package
RUN pip install watchdog

# Create directories
RUN mkdir -p /app/data /shared

COPY watch_folder.py .

CMD ["python", "watch_folder.py"]