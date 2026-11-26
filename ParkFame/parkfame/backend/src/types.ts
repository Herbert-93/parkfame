export type VehicleSize = 'motorcycle' | 'small' | 'medium' | 'large' | 'truck';
export const VEHICLE_SIZES: VehicleSize[] = ['motorcycle', 'small', 'medium', 'large', 'truck'];

export interface SizeRate { label: string; ratePerBlock: number }
export interface RateConfig {
  currency: 'UGX';
  blockHours: number;      // length of one billing block (default 12h)
  graceMinutes: number;    // free minutes at the start
  overstayHours?: number;  // late-pickup window after each block ends before the next block is charged (default 6)
  bikeLongStayDays?: number;       // motorcycles parked longer than this switch to long-stay blocks (default 7, 0 = off)
  bikeLongStayBlockHours?: number; // length of a long-stay block (default 24)
  sizes: Record<VehicleSize, SizeRate>;
}

export interface AppUser {
  uid: string;
  name: string;
  email: string;
  role: 'admin' | 'attendant';
  lotId: string | null;
  /** Admins only. Missing/null = super admin (all lots). An array = lot admin, limited to those lots. */
  lotIds?: string[] | null;
  active: boolean;
}

declare global {
  namespace Express {
    interface Request { user?: AppUser }
  }
}
