FROM node:20-alpine

WORKDIR /usr/src/app

COPY package.json package-lock.json* ./
RUN npm install --production

COPY . .

EXPOSE 4000

CMD ["node", "src/server.js"]
