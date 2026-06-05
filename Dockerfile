# ---------------------------
# Stage 1: Build (Maven)
# ---------------------------
FROM maven:3.9.6-eclipse-temurin-17 AS build

WORKDIR /app

# Copy project
COPY pom.xml .
COPY src ./src

# Build jar
RUN mvn clean package -DskipTests

# ---------------------------
# Stage 2: Runtime (Lightweight)
# ---------------------------
FROM eclipse-temurin:17-jdk

WORKDIR /app

# Copy jar from build stage
COPY --from=build /app/target/*.jar app.jar

# Expose Spring Boot port
EXPOSE 8080

# JVM tuning (important for real banking apps)
ENV JAVA_OPTS="-Xms256m -Xmx512m"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
