FROM node:18-bullseye-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json yarn.lock ./
RUN npm install --omit=dev --no-package-lock

COPY src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
