import { RateConfig, VehicleSize } from './types';

export const defaultRates = (): RateConfig => ({
  currency: 'UGX',
  blockHours: 12,
  graceMinutes: 10,
  sizes: {
    motorcycle: { label: 'Motorcycle', ratePerBlock: 2000 },
    small: { label: 'Small car', ratePerBlock: 5000 },
    medium: { label: 'Medium / Saloon', ratePerBlock: 7000 },
    large: { label: 'SUV / Van', ratePerBlock: 10000 },
    truck: { label: 'Truck / Bus', ratePerBlock: 20000 },
  },
});

export interface Quote {
  minutes: number;
  blocks: number;
  ratePerBlock: number;
  amount: number;
  nextIncreaseAt: string;
}

/** Every started block of `blockHours` is charged: 0-12h = 1x, 12-24h = 2x, 24-36h = 3x ... */
export function calculateFee(entryMs: number, exitMs: number, size: VehicleSize, cfg: RateConfig): Quote {
  const minutes = Math.max(0, Math.ceil((exitMs - entryMs) / 60000));
  const ratePerBlock = cfg.sizes[size].ratePerBlock;
  const blockMs = cfg.blockHours * 3600_000;
  if (minutes <= cfg.graceMinutes) {
    return { minutes, blocks: 0, ratePerBlock, amount: 0, nextIncreaseAt: new Date(entryMs + cfg.graceMinutes * 60000).toISOString() };
  }
  const blocks = Math.max(1, Math.ceil(minutes / (cfg.blockHours * 60)));
  return { minutes, blocks, ratePerBlock, amount: blocks * ratePerBlock, nextIncreaseAt: new Date(entryMs + blocks * blockMs).toISOString() };
}
