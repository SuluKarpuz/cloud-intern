FROM node:16-alpine

WORKDIR /app

COPY package.json ./

RUN npm install --production

COPY app.js .

EXPOSE 80

CMD ["node", "app.js"]
