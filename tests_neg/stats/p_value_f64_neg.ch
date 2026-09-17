module Nautilus.Tests_Neg.Stats.P_Value_F64_Neg
import Nautilus.Stats (likelihood_ratio_p_value)
def p_value_f64(null_ll: f64, alt_ll: f64, df: f64) -> f64 = likelihood_ratio_p_value(null_ll, alt_ll, df)
