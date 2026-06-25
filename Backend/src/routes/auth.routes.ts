import { Router } from "express";
import { asyncHandler } from "../utils/asyncHandler";
import {
  loginHandler,
  signupHandler,
  logoutHandler,
  meHandler
} from "../controllers/auth.controller";
import { requireAuth } from "../middleware/auth.middleware";

const router = Router();

router.post("/signup", asyncHandler(signupHandler));
router.post("/login", asyncHandler(loginHandler));
router.post("/logout", asyncHandler(logoutHandler));
router.get("/me", requireAuth, asyncHandler(meHandler));

export default router;