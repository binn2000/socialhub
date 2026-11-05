export class ApiRequestError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public errors?: Record<string, string[]>
  ) {
    super(message);
    this.name = "ApiRequestError";
  }
}
