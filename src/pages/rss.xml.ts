import { generateRSS } from '@/utils/feed'
import type { APIContext } from 'astro'

export const GET = (context: APIContext) => generateRSS(context)
