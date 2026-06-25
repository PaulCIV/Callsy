import { Router } from "express";
import {
  healthCheck,
  listBusinesses,
  getMyBusiness,
  createBusiness,
  updateBusiness,
  updateMyBusiness,
  provisionMyBusinessNumber,
  releaseMyBusinessNumber,
  listLeads,
  listEvents,
  listSmsEvents
} from "../controllers/health.controller";
import { requireAuth } from "../middleware/auth.middleware";

const router = Router();

router.get("/health", healthCheck);

router.get("/admin/businesses", requireAuth, listBusinesses);
router.get("/admin/businesses/me", requireAuth, getMyBusiness);
router.post("/admin/businesses", requireAuth, createBusiness);
router.patch("/admin/businesses/me", requireAuth, updateMyBusiness);
router.patch("/admin/businesses/:id", requireAuth, updateBusiness);

router.post("/admin/businesses/me/provision-number", requireAuth, provisionMyBusinessNumber);
router.post("/admin/businesses/me/release-number", requireAuth, releaseMyBusinessNumber);

router.get("/admin/leads", requireAuth, listLeads);
router.get("/admin/events", requireAuth, listEvents);
router.get("/admin/sms-events", requireAuth, listSmsEvents);

export default router;