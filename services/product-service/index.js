const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");
const crypto = require("crypto");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.PRODUCTS_TABLE || "shopflow-products";

const response = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;

  try {
    // POST /products
    if (method === "POST" && path === "/products") {
      const { name, description, price, category, stock } = JSON.parse(event.body);
      if (!name || !price) return response(400, { error: "Missing required fields" });

      const productId = crypto.randomUUID();
      await ddb.send(new PutCommand({
        TableName: TABLE,
        Item: { productId, name, description, price, category, stock: stock || 0, createdAt: new Date().toISOString() },
      }));

      return response(201, { productId, name, price, message: "Product created" });
    }

    // GET /products
    if (method === "GET" && path === "/products") {
      const result = await ddb.send(new ScanCommand({ TableName: TABLE }));
      return response(200, { products: result.Items, count: result.Count });
    }

    // GET /products/{productId}
    if (method === "GET" && path.startsWith("/products/")) {
      const productId = path.split("/")[2];
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { productId } }));
      if (!result.Item) return response(404, { error: "Product not found" });
      return response(200, result.Item);
    }

    return response(404, { error: "Route not found" });
  } catch (err) {
    console.error(err);
    return response(500, { error: "Internal server error" });
  }
};
