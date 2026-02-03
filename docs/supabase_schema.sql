-- SUPABASE DATABASE SCHEMA
-- Dance Studio Management System (Kaskad)
-- Version 1.0
-- 2024

-- =====================================================
-- EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- STUDIOS TABLE
-- =====================================================
CREATE TABLE public.studios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    subscription_plan TEXT DEFAULT 'free',
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- PROFILES TABLE
-- =====================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    studio_id UUID REFERENCES public.studios(id) ON DELETE SET NULL,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'child' CHECK (role IN ('superadmin', 'admin', 'teacher', 'parent', 'child')),
    is_superadmin BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_profiles_studio_id ON public.profiles(studio_id);
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);

-- =====================================================
-- GALLERY ITEMS TABLE
-- =====================================================
CREATE TABLE public.gallery_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    studio_id UUID REFERENCES public.studios(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
    category TEXT,
    tags TEXT[],
    is_public BOOLEAN DEFAULT false,
    likes_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_gallery_studio_id ON public.gallery_items(studio_id);
CREATE INDEX idx_gallery_created_at ON public.gallery_items(created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE public.studios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gallery_items ENABLE ROW LEVEL SECURITY;

-- Studios Policies
CREATE POLICY "Super admins can manage all studios" ON public.studios
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.is_superadmin = true
        )
    );

CREATE POLICY "Admins can view studios they belong to" ON public.studios
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.studio_id = studios.id
            AND profiles.role IN ('admin', 'teacher', 'parent', 'child')
        )
    );

-- Profiles Policies
CREATE POLICY "Authenticated users can view profiles" ON public.profiles
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Authenticated users can view all profiles" ON public.profiles
    FOR SELECT USING (auth.role() = 'authenticated');

-- Gallery Policies
CREATE POLICY "Public gallery items are viewable by all" ON public.gallery_items
    FOR SELECT USING (is_public = true);

CREATE POLICY "Studio members can view their gallery" ON public.gallery_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.studio_id = gallery_items.studio_id
        )
    );

CREATE POLICY "Admins and teachers can manage gallery" ON public.gallery_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.studio_id = gallery_items.studio_id
            AND profiles.role IN ('admin', 'teacher')
        )
    );

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger
CREATE TRIGGER handle_studios_updated_at
    BEFORE UPDATE ON public.studios
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_gallery_updated_at
    BEFORE UPDATE ON public.gallery_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =====================================================
-- INITIAL DATA
-- =====================================================

-- Insert Kaskad studio
INSERT INTO public.studios (id, name, description, subscription_plan, active)
VALUES (
    '123e4567-e89b-12d3-a456-426614174000',
    'Kaskad',
    'Танцевальная студия Kaskad',
    'premium',
    true
);

-- =====================================================
-- VIEWS
-- =====================================================

CREATE OR REPLACE VIEW public.profiles_with_studio AS
SELECT 
    p.*,
    s.name as studio_name,
    s.description as studio_description
FROM public.profiles p
LEFT JOIN public.studios s ON p.studio_id = s.id;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE public.studios IS 'Таблица танцевальных студий';
COMMENT ON TABLE public.profiles IS 'Профили пользователей';
COMMENT ON TABLE public.gallery_items IS 'Элементы галереи';
COMMENT ON VIEW public.profiles_with_studio IS 'Профили с информацией о студии';
