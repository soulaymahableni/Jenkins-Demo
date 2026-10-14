FROM eclipse-temurin:17-jre
EXPOSE 8080
WORKDIR /app
COPY target/*.jar app.jar
CMD ["java", "-jar", "app.jar"]
