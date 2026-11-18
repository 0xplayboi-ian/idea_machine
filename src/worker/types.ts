export type Bucket = "eliminated" | "cut_by_rank" | "active";

export type Idea = {
  id: string;
  name: string;
  status: Bucket;
  composite: number;
  times_reinstated: number;
  cut_at_run?: number | null;
};
