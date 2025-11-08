openapi: 3.0.3
info:
  title: Accounts Automation API
  description: API para criação e busca de contas internas
  version: 1.0.0

paths:
  /accounts:
    get:
      summary: Busca conta por AccountEmail ou AccountId
      parameters:
        - name: accountEmail
          in: query
          required: false
          description: E-mail da conta
          schema:
            type: string
            format: email
        - name: accountId
          in: query
          required: false
          description: ID da conta
          schema:
            type: string
      responses:
        '200':
          description: Conta encontrada
          content:
            application/json:
              schema:
                type: object
        '400':
          description: Parâmetro ausente
        '404':
          description: Conta não encontrada
        '500':
          description: Erro interno
      security:
        - sigv4: []
      x-amazon-apigateway-integration:
        uri: arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${region}:${account_id}:function:${name}/invocations
        passthroughBehavior: when_no_match
        httpMethod: GET
        type: aws_proxy

    post:
      summary: Cria uma nova conta
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                AccountEmail:
                  type: string
                  format: email
                AccountName:
                  type: string
                OrgUnit:
                  type: string
                SSOUserEmail:
                  type: string
                  format: email
                SSOUserFirstName:
                  type: string
                SSOUserLastName:
                  type: string
                Tags:
                  type: array
                  items:
                    type: object
                    properties:
                      Key: { type: string }
                      Value: { type: string }
              required:
                - AccountEmail
                - AccountName
                - OrgUnit
                - SSOUserEmail
                - SSOUserFirstName
                - SSOUserLastName
      responses:
        '201':
          description: Conta criada
          content:
            application/json:
              schema:
                type: object
        '400':
          description: Falha na validação
        '409':
          description: Conta já existe
        '500':
          description: Erro interno
      security:
        - sigv4: []
      x-amazon-apigateway-integration:
        uri: arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${region}:${account_id}:function:${name}/invocations
        passthroughBehavior: when_no_match
        httpMethod: POST
        type: aws_proxy

components:
  securitySchemes:
    sigv4:
      type: apiKey
      name: Authorization
      in: header