module Nautilus.Tests.GammaSamplingParity
import Nautilus.Distributions (gamma_sample, chi_squared_sample, student_t_sample)
small = to_tensor([0.0f32])
three = to_tensor([0.0f32, 0.0f32, 0.0f32])
gamma_three = gamma_sample(key_from_seed(33i64), copy(three), 2.0f32, 1.0f32)
gamma_one = gamma_sample(key_from_seed(13i64), small, 1.0f32, 2.0f32)
chi_three = chi_squared_sample(key_from_seed(34i64), copy(three), 4.0f32)
student_three = student_t_sample(key_from_seed(35i64), three, 4.0f32)
