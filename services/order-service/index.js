const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const crypto = require("crypto");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.ORDERS_TABLE || "shopflow-orders";

const response = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;

  try {
    // POST /orders
    if (method === "POST" && path === "/orders") {
      const { userId, items, totalAmount } = JSON.parse(event.body);
      if (!userId || !items || !totalAmount) return response(400, { error: "Missing required fields" });

      const orderId = crypto.randomUUID();
      await ddb.send(new PutCommand({
        TableName: TABLE,
        Item: {
          orderId,
          userId,
          items,
          totalAmount,
          status: "PENDING",
          createdAt: new Date().toISOString(),
        },
      }));

      return response(201, { orderId, userId, status: "PENDING", message: "Order placed" });
    }

    // GET /orders/{orderId}
    if (method === "GET" && path.startsWith("/orders/") && !path.includes("/user/")) {
      const orderId = path.split("/")[2];
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { orderId } }));
      if (!result.Item) return response(404, { error: "Order not found" });
      return response(200, result.Item);
    }

    // GET /orders/user/{userId}
    if (method === "GET" && path.includes("/user/")) {
      const userId = path.split("/user/")[1];
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: "userId-index",
        KeyConditionExpression: "userId = :uid",
        ExpressionAttributeValues: { ":uid": userId },
      }));
      return response(200, { orders: result.Items, count: result.Count });
    }

    // PATCH /orders/{orderId}/status
    if (method === "PATCH" && path.includes("/status")) {
      const orderId = path.split("/")[2];
      const { status } = JSON.parse(event.body);
      const validStatuses = ["PENDING", "CONFIRMED", "SHIPPED", "DELIVERED", "CANCELLED"];
      if (!validStatuses.includes(status)) return response(400, { error: "Invalid status" });

      const { UpdateCommand } = require("@aws-sdk/lib-dynamodb");
      await ddb.send(new UpdateCommand({
        TableName: TABLE,
        Key: { orderId },
        UpdateExpression: "SET #s = :status, updatedAt = :updatedAt",
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: { ":status": status, ":updatedAt": new Date().toISOString() },
      }));

      return response(200, { orderId, status, message: "Order status updated" });
    }

    return response(404, { error: "Route not found" });
  } catch (err) {
    console.error(err);
    return response(500, { error: "Internal server error" });
  }
};
