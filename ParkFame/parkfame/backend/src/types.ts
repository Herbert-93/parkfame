export type VehicleSize = 'motorcycle' | 'small' | 'medium' | 'large' | 'truck';
export const VEHICLE_SIZES: VehicleSize[] = ['motorcycle', 'small', 'medium', 'large', 'truck'];

export interface SizeRate { label: string; ratePerBlock: number }
export interface RateConfig {
  currency: 'UGX';
  blockHours: number;      // length of one billing block (default 12h)
  graceMinutes: number;    // free minutes at the start
  sizes: Record<VehicleSize, SizeRate>;
}

export interface AppUser {
  uid: string;
  name: string;
  email: string;
  role: 'admin' | 'attendant';
  lotId: string | null;
  active: boolean;
}

declare global {
  namespace Express {
    interface Request { user?: AppUser }
  }
}
