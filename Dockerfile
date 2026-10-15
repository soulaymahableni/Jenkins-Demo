FROM eclipse-temurin:17-jre
EXPOSE 2222
WORKDIR /app
COPY target/*.jar app.jar
CMD ["java", "-jar", "app.jar"]
