"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { Compass } from "@/components/Compass";

export default function LoginPage() {
  const router = useRouter();
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error } = isSignUp
      ? await supabase.auth.signUp({ email, password })
      : await supabase.auth.signInWithPassword({ email, password });

    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/walks");
  }

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-8 p-6">
      <Compass />
      <div className="tc-cartouche w-full max-w-sm">
        <form onSubmit={handleSubmit} className="flex flex-col gap-6">
          <div className="text-center">
            <h1 className="tc-title-xl">{isSignUp ? "Join Trail" : "Trail"}</h1>
            <p className="tc-caption mt-1">Walks, drawn in ink on paper</p>
          </div>
          <label className="tc-field">
            <span className="tc-label">Email</span>
            <input
              type="email"
              placeholder="you@example.com"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </label>
          <label className="tc-field">
            <span className="tc-label">Password</span>
            <input
              type="password"
              placeholder="At least 8 characters"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
          {error && <p className="tc-error">{error}</p>}
          <button type="submit" disabled={loading} className="tc-btn tc-btn--primary tc-btn--block">
            {loading ? "Please wait" : isSignUp ? "Sign up" : "Sign in"}
          </button>
          <div className="text-center">
            <button type="button" onClick={() => setIsSignUp(!isSignUp)} className="tc-link">
              {isSignUp ? "I already have an account" : "Create an account"}
            </button>
          </div>
        </form>
      </div>
    </main>
  );
}
