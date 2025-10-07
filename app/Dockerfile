# Use a base Python image
FROM python:3.13-slim

# Set the working directory in the container
WORKDIR /app

# Set the USERNAME environment variable
ENV USERNAME=fastapi-user

ARG ARGO_TOKEN
ENV ARGO_TOKEN=$ARGO_TOKEN

# TODO: make sure Docker has access to environment variable

# Copy requirements.txt and install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Expose the port the app will run on
EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]