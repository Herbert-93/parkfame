import { RateConfig, VehicleSize } from './types';

export const DEFAULT_OVERSTAY_HOURS = 6;
export const DEFAULT_BIKE_LONG_STAY_DAYS = 7;
export const DEFAULT_BIKE_LONG_STAY_BLOCK_HOURS = 24;

export const defaultRates = (): RateConfig => ({
  currency: 'UGX',
  blockHours: 12,
  graceMinutes: 10,
  overstayHours: DEFAULT_OVERSTAY_HOURS,
  bikeLongStayDays: DEFAULT_BIKE_LONG_STAY_DAYS,
  bikeLongStayBlockHours: DEFAULT_BIKE_LONG_STAY_BLOCK_HOURS,
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
  longBlocks?: number; // motorcycles only: how many of `blocks` are long-stay (24h) blocks
}

/**
 * Billing rules
 *  - first `graceMinutes` are free
 *  - every started block of `blockHours` is charged: 0-12h = 1x, then a 2nd block ...
 *  - ...but the next block only starts counting `overstayHours` (default 6h) AFTER the previous block ends,
 *    so a car collected up to 18h after entry still pays 1x, up to 30h pays 2x, and so on
 *  - motorcycles parked longer than `bikeLongStayDays` (default 7) are then billed per `bikeLongStayBlockHours`
 *    (default 24h) instead, at the motorcycle block rate
 * Older lots/sessions saved before these settings existed fall back to the defaults.
 */
export function calculateFee(entryMs: number, exitMs: number, size: VehicleSize, cfg: RateConfig): Quote {
  const minutes = Math.max(0, Math.ceil((exitMs - entryMs) / 60000));
  const ratePerBlock = cfg.sizes[size].ratePerBlock;
  const blockMin = cfg.blockHours * 60;
  const windowMin = Math.round((cfg.overstayHours ?? DEFAULT_OVERSTAY_HOURS) * 60);
  const longDays = cfg.bikeLongStayDays ?? DEFAULT_BIKE_LONG_STAY_DAYS;
  const longMin = (cfg.bikeLongStayBlockHours ?? DEFAULT_BIKE_LONG_STAY_BLOCK_HOURS) * 60;
  const at = (m: number) => new Date(entryMs + m * 60000).toISOString();

  if (minutes <= cfg.graceMinutes) {
    return { minutes, blocks: 0, ratePerBlock, amount: 0, nextIncreaseAt: at(cfg.graceMinutes) };
  }

  // block k (k >= 2) starts being charged at (k-1)*block + window
  const stdBlocks = 1 + Math.max(0, Math.ceil((minutes - windowMin) / blockMin) - 1);

  if (size === 'motorcycle' && longDays > 0) {
    const stdMax = Math.ceil((longDays * 1440) / blockMin);
    const paidUntil = stdMax * blockMin;
    const blocksStd = Math.min(stdBlocks, stdMax);
    const longBlocks = minutes > paidUntil + windowMin ? Math.ceil((minutes - paidUntil - windowMin) / longMin) : 0;
    const blocks = blocksStd + longBlocks;
    const next = blocksStd >= stdMax ? paidUntil + windowMin + longBlocks * longMin : blocksStd * blockMin + windowMin;
    return { minutes, blocks, ratePerBlock, amount: blocks * ratePerBlock, nextIncreaseAt: at(next), longBlocks };
  }

  return { minutes, blocks: stdBlocks, ratePerBlock, amount: stdBlocks * ratePerBlock, nextIncreaseAt: at(stdBlocks * blockMin + windowMin) };
}
