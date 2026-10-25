FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/Enotes.Api/Enotes.Api.csproj src/Enotes.Api/
RUN dotnet restore src/Enotes.Api/Enotes.Api.csproj

COPY src/Enotes.Api/ src/Enotes.Api/
RUN dotnet publish src/Enotes.Api/Enotes.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app/publish .

ENV Notes__DatabasePath=/data/notes.db
EXPOSE 36241
ENTRYPOINT ["dotnet", "Enotes.Api.dll"]
