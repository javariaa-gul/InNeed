import {
  IsString, IsNotEmpty, IsNumber, IsOptional,
  IsBoolean, IsEnum, Min,
} from 'class-validator';

export class CreateJobDto {
  @IsString() @IsNotEmpty()
  title: string;

  @IsString() @IsNotEmpty()
  description: string;

  @IsOptional() @IsString()
  skillRequired?: string;

  @IsEnum(['fixed', 'hourly'])
  pricingType: string;

  @IsNumber() @Min(1)
  price: number;

  @IsOptional() @IsEnum(['any', 'male', 'female'])
  genderPreference?: string;

  @IsOptional() @IsEnum(['urgent', 'today', 'flexible'])
  urgency?: string;

  @IsOptional() @IsNumber()
  locationLat?: number;

  @IsOptional() @IsNumber()
  locationLon?: number;

  @IsOptional() @IsString()
  locationAddress?: string;

  @IsOptional() @IsBoolean()
  isRemote?: boolean;

  @IsOptional() @IsNumber() @Min(0.5)
  estimatedHours?: number;

  @IsOptional() @IsString()
  requiredByTime?: string;

  @IsOptional() @IsString()
  attachmentUrls?: string;
}
