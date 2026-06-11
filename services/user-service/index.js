const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand } = require("@aws-sdk/lib-dynamodb");
const crypto = require("crypto");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.USERS_TABLE || "shopflow-users";

const response = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;

  try {
    // POST /users/register
    if (method === "POST" && path === "/users/register") {
      const { name, email, password } = JSON.parse(event.body);
      if (!name || !email || !password) return response(400, { error: "Missing fields" });

      const userId = crypto.randomUUID();
      const passwordHash = crypto.createHash("sha256").update(password).digest("hex");

      await ddb.send(new PutCommand({
        TableName: TABLE,
        Item: { userId, name, email, passwordHash, createdAt: new Date().toISOString() },
        ConditionExpression: "attribute_not_exists(email)",
      }));

      return response(201, { userId, name, email, message: "User registered" });
    }

    // GET /users/{userId}
    if (method === "GET" && path.startsWith("/users/")) {
      const userId = path.split("/")[2];
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { userId } }));
      if (!result.Item) return response(404, { error: "User not found" });

      const { passwordHash, ...user } = result.Item;
      return response(200, user);
    }

    // POST /users/login
    if (method === "POST" && path === "/users/login") {
      const { userId, password } = JSON.parse(event.body);
      const passwordHash = crypto.createHash("sha256").update(password).digest("hex");

      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { userId } }));
      if (!result.Item || result.Item.passwordHash !== passwordHash)
        return response(401, { error: "Invalid credentials" });

      return response(200, { message: "Login successful", userId });
    }

    return response(404, { error: "Route not found" });
  } catch (err) {
    console.error(err);
    return response(500, { error: "Internal server error" });
  }
};
