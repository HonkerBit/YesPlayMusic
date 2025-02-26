# 使用更高版本的 Node.js 镜像
FROM node:18.17.1-alpine as build

# 设置环境变量
ENV VUE_APP_NETEASE_API_URL=/api

# 设置工作目录
WORKDIR /app

# 替换 Alpine 镜像源为清华镜像源，并安装必要的依赖
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache python3 make g++ git

# 复制 package.json 和 yarn.lock 并安装依赖
COPY package.json yarn.lock ./
RUN yarn install

# 复制项目文件并构建
COPY . .
RUN yarn config set electron_mirror https://npmmirror.com/mirrors/electron/ && \
    yarn build

# 使用更高版本的 Nginx 镜像
FROM nginx:1.25.2-alpine as app

# 复制构建阶段的 package.json
COPY --from=build /app/package.json /usr/local/lib/

# 替换 Alpine 镜像源为清华镜像源，并安装必要的依赖
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.14/main libuv \
    && apk add --no-cache --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.14/main nodejs npm \
    && npm i -g $(awk -F \" '{if(\$2=="NeteaseCloudMusicApi") print \$2"@"\$4}' /usr/local/lib/package.json) \
    && rm -f /usr/local/lib/package.json

# 复制 Nginx 配置文件
COPY --from=build /app/docker/nginx.conf.example /etc/nginx/conf.d/default.conf

# 复制构建后的文件到 Nginx 的 HTML 目录
COPY --from=build /app/dist /usr/share/nginx/html

# 启动 Nginx 并运行 NeteaseCloudMusicApi
CMD nginx ; exec npx NeteaseCloudMusicApi
