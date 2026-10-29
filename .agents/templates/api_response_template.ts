/**
 * ==============================================================================
 * Utilidad Maestra de Respuestas y Excepciones HTTP (api_response.ts)
 * Compatible con Express, Fastify, NestJS o cualquier runtime Node.js/TypeScript
 * ==============================================================================
 */

export interface ApiResponsePayload<T = unknown> {
  success: boolean;
  data?: T;
  meta?: {
    timestamp: string;
    page?: number;
    limit?: number;
    total?: number;
    totalPages?: number;
    hasNext?: boolean;
    hasPrev?: boolean;
    [key: string]: unknown;
  };
}

export interface ApiErrorPayload {
  success: false;
  error: {
    code: string;
    message: string;
    statusCode: number;
    details?: unknown;
    timestamp: string;
  };
}

/**
 * Envoltorio universal para respuestas HTTP exitosas
 */
export class ApiResponse {
  static success<T>(data: T, meta?: ApiResponsePayload<T>['meta']): ApiResponsePayload<T> {
    return {
      success: true,
      data,
      meta: {
        timestamp: new Date().toISOString(),
        ...meta,
      },
    };
  }

  static paginated<T>(
    items: T[],
    page: number,
    limit: number,
    total: number
  ): ApiResponsePayload<T[]> {
    const totalPages = Math.ceil(total / limit) || 1;
    return {
      success: true,
      data: items,
      meta: {
        timestamp: new Date().toISOString(),
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
    };
  }

  static error(
    code: string,
    message: string,
    statusCode: number = 400,
    details?: unknown
  ): ApiErrorPayload {
    return {
      success: false,
      error: {
        code,
        message,
        statusCode,
        details,
        timestamp: new Date().toISOString(),
      },
    };
  }
}

/**
 * Jerarquía de Excepciones HTTP de Dominio
 */
export class HttpException extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestException extends HttpException {
  constructor(message = 'Parámetros de solicitud inválidos', details?: unknown) {
    super(400, 'ERR_BAD_REQUEST', message, details);
  }
}

export class UnauthorizedException extends HttpException {
  constructor(message = 'Autenticación requerida o token inválido') {
    super(401, 'ERR_UNAUTHORIZED', message);
  }
}

export class ForbiddenException extends HttpException {
  constructor(message = 'Permisos insuficientes para acceder a este recurso') {
    super(403, 'ERR_FORBIDDEN', message);
  }
}

export class NotFoundException extends HttpException {
  constructor(message = 'Recurso solicitado no encontrado') {
    super(404, 'ERR_NOT_FOUND', message);
  }
}

export class ConflictException extends HttpException {
  constructor(message = 'El recurso ya existe o genera un conflicto de estado') {
    super(409, 'ERR_CONFLICT', message);
  }
}

export class UnprocessableEntityException extends HttpException {
  constructor(message = 'Fallo de validación semántica', details?: unknown) {
    super(422, 'ERR_UNPROCESSABLE_ENTITY', message, details);
  }
}

export class InternalServerErrorException extends HttpException {
  constructor(message = 'Error interno en el servidor') {
    super(500, 'ERR_INTERNAL_SERVER', message);
  }
}

/**
 * Middleware Express para manejo global de errores (Ejemplo de uso)
 * 
 * import { errorHandler } from './api_response';
 * app.use(errorHandler);
 */
export function errorHandler(err: unknown, req: unknown, res: any, next: unknown) {
  if (err instanceof HttpException) {
    return res.status(err.statusCode).json(
      ApiResponse.error(err.code, err.message, err.statusCode, err.details)
    );
  }

  // Si es un error desconocido o no controlado, nunca exponer el stack trace en producción
  console.error('[UnhandledError]', err);
  const isDev = process.env.NODE_ENV === 'development';
  return res.status(500).json(
    ApiResponse.error(
      'ERR_INTERNAL_SERVER',
      'Ha ocurrido un error inesperado en el servidor',
      500,
      isDev ? (err as Error)?.message : undefined
    )
  );
}
