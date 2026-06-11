FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install --production
COPY index.js .
EXPOSE 3000
CMD ["node", "-e", "console.log('Product Service container ready')"]
