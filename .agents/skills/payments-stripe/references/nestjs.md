# Pagos con Stripe — NestJS + Prisma / PostgreSQL

Receta de referencia para `stack-nestjs-postgres`. Explica la configuración de `rawBody: true` en `main.ts`, inyección de dependencias en un módulo dedicado (`BillingModule`), verificación segura con `@Req() req: RawBodyRequest<Request>` e idempotencia en PostgreSQL.

## 1. Configuración de Raw Body en NestJS (`src/main.ts`)

```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    rawBody: true, // Habilita req.rawBody para webhooks criptográficos
  });

  app.setGlobalPrefix('api');
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
```

## 2. Controlador de Facturación (`src/modules/billing/billing.controller.ts`)

```ts
import {
  Controller,
  Post,
  Headers,
  Req,
  BadRequestException,
  HttpCode,
  HttpStatus,
  UseGuards,
  Body,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { BillingService } from './billing.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('billing')
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async handleWebhook(
    @Headers('stripe-signature') sig: string,
    @Req() req: RawBodyRequest<Request>,
  ) {
    if (!sig) {
      throw new BadRequestException('Missing stripe-signature header');
    }
    if (!req.rawBody) {
      throw new BadRequestException('Raw request body unavailable');
    }

    return this.billingService.processWebhook(req.rawBody, sig);
  }

  @Post('checkout')
  @UseGuards(JwtAuthGuard)
  async createCheckout(
    @CurrentUser('id') userId: string,
    @Body('planKey') planKey: string,
  ) {
    return this.billingService.createCheckoutSession(userId, planKey);
  }
}
```

## 3. Servicio de Facturación (`src/modules/billing/billing.service.ts`)

```ts
import { Injectable, BadRequestException, InternalServerErrorException } from '@nestjs/common';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class BillingService {
  private stripe: Stripe;

  constructor(private prisma: PrismaService) {
    this.stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
      apiVersion: '2025-02-24.acacia' as any,
    });
  }

  async processWebhook(rawBody: Buffer, signature: string) {
    let event: Stripe.Event;
    try {
      event = this.stripe.webhooks.constructEvent(
        rawBody,
        signature,
        process.env.STRIPE_WEBHOOK_SECRET!,
      );
    } catch (err: any) {
      throw new BadRequestException(`Webhook signature verification failed: ${err.message}`);
    }

    // Comprobar idempotencia
    const processed = await this.prisma.stripeEvent.findUnique({
      where: { eventId: event.id },
    });
    if (processed) {
      return { received: true, duplicate: true };
    }

    // Consultas a Stripe fuera de la transacción DB
    const sub = event.type.startsWith('customer.subscription.')
      ? await this.stripe.subscriptions.retrieve((event.data.object as Stripe.Subscription).id)
      : null;

    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.stripeEvent.create({
          data: { eventId: event.id, type: event.type },
        });

        if (sub) {
          await tx.subscription.upsert({
            where: { stripeSubscriptionId: sub.id },
            create: {
              stripeSubscriptionId: sub.id,
              userId: sub.metadata.userId,
              status: sub.status,
              priceId: sub.items.data[0].price.id,
              currentPeriodEnd: new Date(sub.current_period_end * 1000),
              cancelAtPeriodEnd: sub.cancel_at_period_end,
            },
            update: {
              status: sub.status,
              priceId: sub.items.data[0].price.id,
              currentPeriodEnd: new Date(sub.current_period_end * 1000),
              cancelAtPeriodEnd: sub.cancel_at_period_end,
            },
          });
        }
      });
    } catch (error) {
      throw new InternalServerErrorException('Error processing stripe webhook transaction');
    }

    return { received: true };
  }
}
```
