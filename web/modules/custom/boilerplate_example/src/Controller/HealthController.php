<?php

declare(strict_types=1);

namespace Drupal\boilerplate_example\Controller;

use Drupal\Core\Controller\ControllerBase;
use Symfony\Component\HttpFoundation\JsonResponse;

/**
 * Exposes a simple health endpoint.
 */
final class HealthController extends ControllerBase {

  /**
   * Returns an HTTP 200 payload for readiness checks.
   *
   * @return \Symfony\Component\HttpFoundation\JsonResponse
   *   A health payload.
   */
  public function health(): JsonResponse {
    return new JsonResponse([
      'status' => 'ok',
      'service' => 'drupal',
    ]);
  }

}
