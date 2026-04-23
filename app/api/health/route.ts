export function GET() {
  return Response.json({
    status: "ok",
    service: "mirxa-kali",
    timestamp: new Date().toISOString(),
  });
}
