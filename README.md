# TAMA Store — Pink / White / Black

Static Vercel-ready storefront using Supabase.

## Fitur
- Public catalog with search
- Admin `/admin` with Supabase Auth
- Add/edit/delete products
- 1 thumbnail + multiple specification images
- Product price is managed directly; no budget category is required.
- Pink / white / black UI with dark mode
- Username-only customer login
- Live chat by username + category, with admin replies and close chat
- Ratings/reviews with username field, stars, and text
- Hamburger menu with Community, TikTok, and WhatsApp links
- Product details include a “Lanjutkan via WhatsApp” button
- Supabase RLS + exact-parameter RPC for chat

## Setup
1. Create a Supabase project.
2. In Authentication → Users, create `fyesty8@gmail.com` and set its password there.
3. Open SQL Editor and run **all** of `supabase.sql`. This script is safe to rerun and repairs the bucket, the `reviews.text` column, and the Live Chat RPC signature/schema cache.
4. In Vercel → Project → Settings → Environment Variables, add:
   - `SUPABASE_URL` = your Supabase project URL
   - `SUPABASE_ANON_KEY` = your Supabase **anon/publishable** key
5. Deploy/redeploy the project to Vercel. The browser receives the public anon key through `/api/config`; the key itself is not stored in the repository.
6. Public site is `/`, admin panel is `/admin`.

## Important
- Do NOT put a Supabase `service_role` key in the browser or in `SUPABASE_ANON_KEY`.
- `SUPABASE_ANON_KEY` is the browser-safe public key; keep privileged server keys out of the frontend.
- Do NOT hard-code the admin password in frontend code. Supabase Auth handles it.
- The blue banner supplied by the user is stored as `assets/banner.png`.
